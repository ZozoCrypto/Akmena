const fs = require('fs');
const path = require('path');
const OUT_DIR = path.join(__dirname, '../../../out');
const ABI_DIR = path.join(__dirname, '../src/abis');
const contracts = ['AkmenaCore', 'WorkflowEngine', 'AgentRegistry', 'EscrowEngine', 'PaymentsEngine'];

if (!fs.existsSync(ABI_DIR)) fs.mkdirSync(ABI_DIR, { recursive: true });

contracts.forEach(name => {
    const artifactPath = path.join(OUT_DIR, `${name}.sol`, `${name}.json`);
    if (fs.existsSync(artifactPath)) {
        const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
        const tsContent = `export const ${name}ABI = ${JSON.stringify(artifact.abi, null, 2)} as const;\n`;
        fs.writeFileSync(path.join(ABI_DIR, `${name}.ts`), tsContent);
        console.log(`Extracted ABI for ${name}`);
    } else {
        console.error(`Missing artifact for ${name}`);
    }
});
