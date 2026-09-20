import { describe, expect, it, vi } from 'vitest';
import { base } from 'viem/chains';
import { MarketplaceModule } from '../src/modules/MarketplaceModule';
import { WalletRequiredError } from '../src/errors';

describe('MarketplaceModule', () => {
    const moduleAddress =
        '0x2222222222222222222222222222222222222222' as `0x${string}`;

    const accountAddress =
        '0x1111111111111111111111111111111111111111' as `0x${string}`;

    function createHarness(withWallet = true) {
        const simulateContract = vi.fn().mockResolvedValue({
            request: { mocked: true },
        });

        const writeContract = vi.fn().mockResolvedValue(
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );

        const waitForTransactionReceipt = vi.fn().mockResolvedValue({
            gasUsed: 12345n,
            status: 'success',
            transactionHash:
                '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            logs: [],
        });

        const readContract = vi.fn().mockResolvedValue({
            creator: accountAddress,
            assignee:
                '0x3333333333333333333333333333333333333333',
            reward: 1000n,
            status: 1,
        });

        const client = {
            publicClient: {
                simulateContract,
                waitForTransactionReceipt,
                readContract,
            },
            walletClient: withWallet
                ? {
                      account: { address: accountAddress },
                      writeContract,
                  }
                : undefined,
            resolveModule: vi.fn().mockResolvedValue(moduleAddress),
        } as any;

        return {
            module: new MarketplaceModule(client),
            client,
            simulateContract,
            writeContract,
            waitForTransactionReceipt,
            readContract,
        };
    }

    it('requires a wallet for create', async () => {
        const { module } = createHarness(false);

        await expect(module.create(1000n)).rejects.toBeInstanceOf(
            WalletRequiredError,
        );
    });

    it('calls createTask with the reward', async () => {
        const { module, simulateContract } = createHarness();

        await module.create(1000n);

        expect(simulateContract).toHaveBeenCalledWith(
            expect.objectContaining({
                address: moduleAddress,
                functionName: 'createTask',
                args: [1000n],
            }),
        );
    });

    it('calls assignTask with the requested assignee', async () => {
        const { module, simulateContract } = createHarness();

        const assignee =
            '0x3333333333333333333333333333333333333333' as `0x${string}`;

        await module.assign(7n, assignee);

        expect(simulateContract).toHaveBeenCalledWith(
            expect.objectContaining({
                address: moduleAddress,
                functionName: 'assignTask',
                args: [7n, assignee],
            }),
        );
    });

    it('binds completeTask caller to the connected wallet', async () => {
        const { module, simulateContract } = createHarness();

        await module.complete(7n);

        expect(simulateContract).toHaveBeenCalledWith(
            expect.objectContaining({
                address: moduleAddress,
                functionName: 'completeTask',
                args: [7n, accountAddress],
            }),
        );
    });

    it('reads a task through the canonical marketplace module', async () => {
        const { module, readContract } = createHarness();

        const task = await module.get(7n);

        expect(readContract).toHaveBeenCalledWith({
            address: moduleAddress,
            abi: expect.any(Array),
            functionName: 'getTask',
            args: [7n],
        });

        expect(task.reward).toBe(1000n);
    });
});
