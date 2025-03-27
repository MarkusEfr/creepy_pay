import { ethers } from 'ethers';
import fs from 'fs';
import path from 'path';

// ENV config
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.PAYMENT_PROCESSOR;

// Load ABI
const abiPath = path.resolve('assets', 'abi.json');
const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

// Setup wallet
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);

// CLI args
const [, , command, madness_key, recipient, trace_id, value] = process.argv;

async function main() {
    if (command === 'offerBloodOath') {
        try {
            const data = contract.interface.encodeFunctionData('offerBloodOath', [
                madness_key,
                trace_id
            ]);

            const tx = {
                to: CONTRACT_ADDRESS,
                data,
                value: ethers.toBigInt(value)
            };

            await wallet.estimateGas(tx);

            const ethLink = `ethereum:${tx.to}@11155111?value=${value}&data=${data}`;

            console.log(
                JSON.stringify({
                    to: tx.to,
                    value: tx.value.toString(),
                    data,
                    link: ethLink
                })
            );
            process.exit(0);
        } catch (err) {
            console.error(JSON.stringify({
                status: 'failed',
                error: err.message,
                reason: err.reason || null,
                code: err.code || null,
                tx: err.transaction || null
            }, null, 2))
            process.exit(1);
        }
    }

    if (command === 'unleashDamnation') {
        try {
            const tx = await contract.unleashDamnation(madness_key, recipient);
            const receipt = await tx.wait();
            console.log(JSON.stringify({ status: 'ok', receipt }));
            process.exit(0);
        } catch (err) {
            const reason =
                err.reason ||
                (err.error && err.error.reason) ||
                (err.revert && err.revert.args && err.revert.args[0]) ||
                err.message;

            console.log(JSON.stringify({ status: 'failed', reason: reason || 'Unknown' }));
            process.exit(1);
        }
    }

    if (command === 'scryInfernalBalance') {
        try {
            const balance = await contract.scryInfernalBalance(madness_key);
            console.log(balance.toString());
            process.exit(0);
        } catch (err) {
            console.error('Tx failed:', err.message);
            process.exit(1);
        }
    }
}

main();
