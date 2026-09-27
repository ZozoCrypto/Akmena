import { useCallback } from 'react';
import type { Address, Hex } from 'viem';
import {
  getAddress,
  hashTypedData,
  recoverTypedDataAddress,
} from 'viem';
import {
  useAccount,
  usePublicClient,
  useSignTypedData,
} from 'wagmi';

import type { ApprovalModel } from './approvalTypes';
import { useAkmenaState } from '../../state';

const EXECUTION_INTENT_TYPES = {
  ExecutionIntent: [
    { name: 'operator', type: 'address' },
    { name: 'agent', type: 'address' },
    { name: 'target', type: 'address' },
    { name: 'selector', type: 'bytes4' },
    { name: 'calldataHash', type: 'bytes32' },
    { name: 'amount', type: 'uint256' },
    { name: 'value', type: 'uint256' },
    { name: 'proofModuleKey', type: 'bytes32' },
    { name: 'proofId', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'validAfter', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
} as const;

const EXECUTION_AUTHORIZATION_ABI = [
  {
    type: 'function',
    name: 'usedNonces',
    stateMutability: 'view',
    inputs: [
      { name: 'agent', type: 'address' },
      { name: 'nonce', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const;

const ERC1271_ABI = [
  {
    type: 'function',
    name: 'isValidSignature',
    stateMutability: 'view',
    inputs: [
      { name: 'hash', type: 'bytes32' },
      { name: 'signature', type: 'bytes' },
    ],
    outputs: [{ name: 'magicValue', type: 'bytes4' }],
  },
] as const;

const ERC1271_MAGIC_VALUE = '0x1626ba7e' as Hex;

function sameAddress(a: Address, b: Address): boolean {
  return getAddress(a) === getAddress(b);
}

function sameHex(a: Hex, b: Hex): boolean {
  return a.toLowerCase() === b.toLowerCase();
}

export function useApproveExecutionIntent() {
  const akmena = useAkmenaState();
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { signTypedDataAsync } = useSignTypedData();

  const approveExecutionIntent = useCallback(
    async (approval: ApprovalModel): Promise<Hex> => {
      if (!address) {
        throw new Error('Connect the operator wallet before signing.');
      }

      if (!akmena.walletConnected || !akmena.walletAddress) {
        throw new Error('Operator wallet is not connected.');
      }

      if (!publicClient) {
        throw new Error('No live public client is available.');
      }

      if (akmena.walletChainId !== akmena.configuredChainId) {
        throw new Error(
          `Wrong network. Expected chain ${akmena.configuredChainId}.`,
        );
      }

      if (akmena.protocolStatus === 'paused') {
        throw new Error('Akmena is paused. Signing is blocked.');
      }

      if (akmena.protocolStatus !== 'healthy') {
        throw new Error(
          `Protocol state is not healthy: ${akmena.protocolStatus}.`,
        );
      }

      if (akmena.authorizationStatus !== 'live') {
        throw new Error(
          `Execution authorization is not live: ${akmena.authorizationStatus}.`,
        );
      }

      if (!akmena.executionAuthorizationAddress) {
        throw new Error(
          'No live execution authorization contract is available.',
        );
      }

      if (!akmena.eip712Domain) {
        throw new Error('Live EIP-712 domain is unavailable.');
      }

      const operator = getAddress(approval.operator);
      const connected = getAddress(address);
      const liveAuthorization = getAddress(
        akmena.executionAuthorizationAddress,
      );

      if (!sameAddress(operator, connected)) {
        throw new Error(
          'Approval operator does not match the connected wallet.',
        );
      }

      const expectedAuthorization = getAddress(
        akmena.executionAuthorizationAddress,
      );

      if (
        !sameAddress(
          approval.domain.verifyingContract,
          expectedAuthorization,
        )
      ) {
        throw new Error(
          'Approval verifying contract does not match live authorization.',
        );
      }

      if (
        !sameAddress(
          akmena.eip712Domain.verifyingContract,
          liveAuthorization,
        )
      ) {
        throw new Error(
          'Live EIP-712 verifying contract does not match authorization.',
        );
      }

      if (
        akmena.eip712Domain.name !== approval.domain.name ||
        akmena.eip712Domain.version !== approval.domain.version
      ) {
        throw new Error(
          'Approval EIP-712 domain name/version is stale or mismatched.',
        );
      }

      if (
        BigInt(akmena.eip712Domain.chainId) !==
        BigInt(akmena.configuredChainId)
      ) {
        throw new Error(
          'Live EIP-712 domain chain ID does not match the configured network.',
        );
      }

      if (
        BigInt(approval.domain.chainId) !==
        BigInt(akmena.configuredChainId)
      ) {
        throw new Error(
          'Approval domain chain ID does not match the configured network.',
        );
      }

      const now = BigInt(Math.floor(Date.now() / 1000));

      if (now < approval.validAfter) {
        throw new Error('This approval is not valid yet.');
      }

      if (now >= approval.deadline) {
        throw new Error('This approval has expired.');
      }

      const blockingCheck = approval.securityChecks.find(
        (check) => check.status === 'fail',
      );

      if (blockingCheck) {
        throw new Error(
          `Approval blocked by security check: ${blockingCheck.label}.`,
        );
      }

      const nonceAlreadyUsed = await publicClient.readContract({
        address: expectedAuthorization,
        abi: EXECUTION_AUTHORIZATION_ABI,
        functionName: 'usedNonces',
        args: [approval.agent, approval.nonce],
      });

      if (nonceAlreadyUsed) {
        throw new Error(
          `Execution nonce ${approval.nonce.toString()} has already been used.`,
        );
      }

      const domain = {
        name: approval.domain.name,
        version: approval.domain.version,
        chainId: BigInt(approval.domain.chainId),
        verifyingContract: approval.domain.verifyingContract,
      } as const;

      const message = {
        operator: approval.operator,
        agent: approval.agent,
        target: approval.target,
        selector: approval.selector,
        calldataHash: approval.calldataHash,
        amount: approval.amount,
        value: approval.value,
        proofModuleKey: approval.proofModuleKey,
        proofId: approval.proofId,
        nonce: approval.nonce,
        validAfter: approval.validAfter,
        deadline: approval.deadline,
      } as const;

      const computedDigest = hashTypedData({
        domain,
        types: EXECUTION_INTENT_TYPES,
        primaryType: 'ExecutionIntent',
        message,
      });

      if (!sameHex(computedDigest, approval.digest)) {
        throw new Error(
          'Approval digest does not match the exact intent being signed.',
        );
      }

      const signature = await signTypedDataAsync({
        account: address,
        domain,
        types: EXECUTION_INTENT_TYPES,
        primaryType: 'ExecutionIntent',
        message,
      });

      /*
       * Verify the wallet response against the exact digest.
       *
       * EOAs are verified by recovering the signer.
       * Contract wallets are verified through ERC-1271.
       */
      const bytecode = await publicClient.getBytecode({
        address: operator,
      });

      const isContractWallet =
        !!bytecode && bytecode !== '0x';

      if (isContractWallet) {
        const magicValue = await publicClient.readContract({
          address: operator,
          abi: ERC1271_ABI,
          functionName: 'isValidSignature',
          args: [computedDigest, signature],
        });

        if (!sameHex(magicValue, ERC1271_MAGIC_VALUE)) {
          throw new Error(
            'Smart wallet rejected the exact EIP-712 authorization.',
          );
        }
      } else {
        const recovered = await recoverTypedDataAddress({
          domain,
          types: EXECUTION_INTENT_TYPES,
          primaryType: 'ExecutionIntent',
          message,
          signature,
        });

        if (!sameAddress(recovered, operator)) {
          throw new Error(
            'Wallet signature does not recover to the authorized operator.',
          );
        }
      }

      return signature;
    },
    [
      address,
      akmena,
      publicClient,
      signTypedDataAsync,
    ],
  );

  return {
    approveExecutionIntent,
  };
}
