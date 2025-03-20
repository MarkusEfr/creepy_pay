// payment_contractor.mjs
import { ethers } from 'ethers';
import fs from 'fs';
import path from 'path';

// Read environment variables
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.PAYMENT_PROCESSOR;

// Load ABI
const abiPath = path.resolve('assets', 'abi.json');
const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

// Setup Provider, Wallet, and Contract
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);

// CLI args
const [, , command, paymentId, stealthWallet, value] = process.argv;

if (command === 'encode_link') {
    const iface = new ethers.Interface([
        "function createPayment(bytes32,address)"
    ]);

    const encoded = iface.encodeFunctionData("createPayment", [
        paymentId,
        stealthWallet
    ]);

    console.log(encoded);
    process.exit(0);
}

if (command === 'create_payment') {
    try {
        const tx = await contract.createPayment(paymentId, stealthWallet, {
            value: ethers.toBigInt(value),
        });

        console.log("Tx sent:", tx.hash);

        const receipt = await tx.wait();
        console.log("Tx mined:", receipt.transactionHash);
        process.exit(0);
    } catch (err) {
        console.error("Tx failed:", err.message);
        process.exit(1);
    }
}
