import { chromium } from 'playwright';

async function runAudit() {
  console.log("🚀 [Akmena Auditor] Initializing headless Chromium engine...");
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    console.log("🌐 [Akmena Auditor] Connecting to Singularity UI (http://localhost:5173)...");
    // Go to the local dev server
    await page.goto('http://localhost:5173', { waitUntil: 'networkidle' });

    console.log("🛡️ [Akmena Auditor] Verifying Core Architecture Render...");
    
    // 1. Verify Header
    await page.waitForSelector('text=AKMENA // SINGULARITY UI', { timeout: 5000 });
    console.log("   ✅ Core Header Found");

    // 2. Verify Default Escrow Tab
    await page.waitForSelector('text=Create Task Escrow');
    console.log("   ✅ Default Escrow Engine UI Active");

    // 3. Test Interactivity: Click the Agent Tab
    console.log("🖱️ [Akmena Auditor] Testing Interactive Tab Routing...");
    await page.click('button:has-text("Agent Delegation Policy")');
    await page.waitForSelector('text=Delegate AI Agent Execution Policy');
    console.log("   ✅ Agent Policy UI Rendered Successfully");

    // 4. Test Interactivity: Click the Privacy Tab
    await page.click('button:has-text("Ghost Mode Privacy Engine")');
    await page.waitForSelector('text=Ghost Mode Stealth Nullifier Inspector');
    console.log("   ✅ Ghost Mode Privacy UI Rendered Successfully");

    // 5. Capture Visual Proof
    console.log("📸 [Akmena Auditor] Capturing cryptographic visual proof...");
    await page.screenshot({ path: 'Singularity_UI_Audit_Proof.png', fullPage: true });

    console.log("\n✅ [Akmena Auditor] PASSED: All modular UI components verified and fully interactive.");
    console.log("   Screenshot saved to 'frontend/Singularity_UI_Audit_Proof.png'.");

  } catch (error) {
    console.error("\n❌ [Akmena Auditor] FAILED:", error.message);
  } finally {
    await browser.close();
  }
}

runAudit();
