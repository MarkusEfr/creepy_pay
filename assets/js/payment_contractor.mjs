// payment_contractor.mjs
import { trace } from 'console';
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
const [, , command, madness_key, recipient, trace_id, value] = process.argv;

if (command === 'offerBloodOath') {
    try {
        const data = contract.interface.encodeFunctionData("offerBloodOath", [madness_key, trace_id]);
        const to = CONTRACT_ADDRESS;
        const valueHex = ethers.toBigInt(value).toString();

        const ethLink = `ethereum:${to}@11155111?value=${value}&data=${data}`;

        console.log(JSON.stringify({
            to: to,
            value: valueHex,
            data: data,
            eth_link: ethLink
        }, null, 2));

        process.exit(0);
    } catch (err) {
        console.error("Failed to prepare tx:", err.message);
        process.exit(1);
    }
}


if (command === 'unleashDamnation') {
    try {
        const tx = await contract.unleashDamnation(madness_key, recipient);
        console.log(tx);
        const receipt = await tx.wait();
        console.log("Tx mined:", receipt.transactionHash);
        process.exit(0);
    }
    catch (err) {
        console.error("Tx failed:", err.message);
        process.exit(1);
    }
}

if (command === 'scryInfernalBalance') {
    try {
        const balance = await contract.scryInfernalBalance(madness_key);
        console.log(balance.toString());
        process.exit(0);
    }
    catch (err) {
        console.error("Tx failed:", err.message);
        process.exit(1);
    }
}


