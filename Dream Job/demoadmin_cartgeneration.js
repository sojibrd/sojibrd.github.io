const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// --- Dynamic Date Generator ---
const getFormattedDate = () => {
  const date = new Date();
  const day = date.getDate();
  const month = date.toLocaleString('en-GB', { month: 'short' }).toLowerCase();
  const year = date.getFullYear();
  return `${day}-${month}-${year}`; // e.g., 18-dec-2025
};

const CONFIG = {
  distPath: 'P:\\Office\\deploy-dist\\ecom_admin-dist\\dist',
  repoPath: 'P:\\Office\\deploy-dist\\ecom_admin-dist',
  targetBranch: 'demoadmin_cartgeneration',
  commitMsg: `admin_panel_${getFormattedDate()}` // Now Dynamic!
};

function run(command, cwd = process.cwd()) {
  try {
    return execSync(command, { cwd, stdio: 'pipe', encoding: 'utf8' }).trim();
  } catch (err) {
    return null;
  }
}

function deploy() {
  console.log(`🚀 Starting Deployment for: ${CONFIG.commitMsg}`);

  // Step 1: Remove folder
  if (fs.existsSync(CONFIG.distPath)) {
    console.log('1. 🗑️ Cleaning old dist...');
    fs.rmSync(CONFIG.distPath, { recursive: true, force: true });
    console.log('✅ Old dist removed.');
  }

  // Step 2: Dist generate
  console.log('2. 🏗️ Generating Ember build...');
  try {
    execSync(`npx ember build --environment=production --output-path="${CONFIG.distPath}"`, { stdio: 'inherit' });
    console.log('✅ Build successful.');
  } catch (e) {
    console.error('❌ Build failed!');
    return;
  }

  // Step 3: Check target git branch
  console.log('3. 🔍 Checking Git Branch...');
  const currentBranch = run('git branch --show-current', CONFIG.repoPath);

  if (currentBranch === CONFIG.targetBranch) {
    console.log(`✅ Branch matched: ${currentBranch}`);

    // Step 4: Commit and Push
    console.log('4. 💾 Staging and Committing...');
    run('git add .', CONFIG.repoPath);

    const hasChanges = run('git status --porcelain', CONFIG.repoPath);
    if (hasChanges) {
      run(`git commit -m "${CONFIG.commitMsg}"`, CONFIG.repoPath);
      console.log(`✅ Committed with: "${CONFIG.commitMsg}"`);
      
      console.log('🛰️ Pushing to remote...');
      run(`git push origin ${CONFIG.targetBranch}`, CONFIG.repoPath);
      console.log('✅ Git Push Completed!');
    } else {
      console.log('ℹ️ No changes to commit.');
    }
  } else {
    console.log(`⚠️ Branch is "${currentBranch || 'unknown'}". Skipping push.`);
  }

  console.log('🎉 Mission Accomplished!');
}

deploy();