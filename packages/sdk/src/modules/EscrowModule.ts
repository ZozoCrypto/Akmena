import { decodeEventLog } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError, WalletRequiredError } from '../errors';
import { EscrowEngineABI } from '../abis/EscrowEngine';

export interface EscrowTransactionResult {
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    escrowId?: bigint;
}

export class EscrowModule {
    constructor(private readonly client: AkmenaClient) {}

    private requireAccount() {
        const account = this.client.walletClient?.account;
        if (!account) {
            throw new WalletRequiredError();
        }
        return account;
    }

    public async create(
        buyer: `0x${string}`,
        seller: `0x${string}`,
        amount: bigint,
        referenceId: `0x${string}` = `0x${'00'.repeat(32)}` as `0x${string}`,
    ): Promise<EscrowTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngineABI,
                functionName: 'createEscrow',
                args: [buyer, seller, amount, referenceId],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            let escrowId: bigint | undefined;

            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({
                        abi: EscrowEngineABI,
                        data: log.data,
                        topics: log.topics,
                    });

                    if (decoded.eventName === 'EscrowCreated') {
                        escrowId = decoded.args.escrowId;
                        break;
                    }
                } catch {
                    // Ignore unrelated logs.
                }
            }

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                escrowId,
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async createWithAsset(
        asset: `0x${string}`,
        buyer: `0x${string}`,
        seller: `0x${string}`,
        amount: bigint,
        referenceId: `0x${string}` = `0x${'00'.repeat(32)}` as `0x${string}`,
    ): Promise<EscrowTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngineABI,
                functionName: 'createEscrow',
                args: [buyer, seller, asset, amount, referenceId],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            let escrowId: bigint | undefined;

            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({
                        abi: EscrowEngineABI,
                        data: log.data,
                        topics: log.topics,
                    });

                    if (decoded.eventName === 'EscrowCreated') {
                        escrowId = decoded.args.escrowId;
                        break;
                    }
                } catch {
                    // Ignore unrelated logs.
                }
            }

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                escrowId,
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async release(escrowId: bigint): Promise<EscrowTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngineABI,
                functionName: 'releaseEscrow',
                args: [escrowId],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async refund(escrowId: bigint): Promise<EscrowTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngineABI,
                functionName: 'refundEscrow',
                args: [escrowId],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async get(escrowId: bigint) {
        const address = await this.client.resolveModule('escrow');

        try {
            return await this.client.publicClient.readContract({
                address,
                abi: EscrowEngineABI,
                functionName: 'getEscrow',
                args: [escrowId],
            });
        } catch (error: unknown) {
            translateContractError(error);
        }
    }
}
