#!/usr/bin/env node

/**
 * Daily Sheets Export
 * Exports daily metrics to Google Sheets
 * Schedule: Run daily (e.g., 09:00 CST via cron or systemd timer)
 * 
 * Prerequisites:
 * - mcporter installed and configured for Google Workspace
 * - Environment variables set or edit config below
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
// Environment variables to set:
// OPENCLAW_DATA_DIR - path to data directory (default: ./data)
// GOOGLE_SHEETS_ID - your Google Sheet ID
// MCPORTER_BIN - path to mcporter binary (default: ~/.npm-global/bin/mcporter)
const DATA_DIR = process.env.OPENCLAW_DATA_DIR || path.join(__dirname, '../data');
const REQUESTS_FILE = path.join(DATA_DIR, 'api-cost-requests.json');
const METRICS_FILE = path.join(DATA_DIR, 'api-cost-metrics.json');

// Google Sheets Configuration
const SHEET_ID = process.env.GOOGLE_SHEETS_ID || 'YOUR_SHEET_ID';
const SHEET_NAME = 'Daily Metrics';
const MCPORTER_BIN = process.env.MCPORTER_BIN || '~/.npm-global/bin/mcporter';

/**
 * Get today's date in CST timezone
 */
function getTodayDateCST() {
  const now = new Date();
  const cstDate = new Date(now.toLocaleString('en-US', { timeZone: 'America/Mexico_City' }));
  const year = cstDate.getFullYear();
  const month = String(cstDate.getMonth() + 1).padStart(2, '0');
  const day = String(cstDate.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Convert Unix timestamp to date string in CST
 */
function timestampToDateCST(timestamp) {
  const date = new Date(timestamp);
  const cstDate = new Date(date.toLocaleString('en-US', { timeZone: 'America/Mexico_City' }));
  const year = cstDate.getFullYear();
  const month = String(cstDate.getMonth() + 1).padStart(2, '0');
  const day = String(cstDate.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Load data from JSON files
 */
function loadData() {
  const requestsData = JSON.parse(fs.readFileSync(REQUESTS_FILE, 'utf8'));
  const metricsData = JSON.parse(fs.readFileSync(METRICS_FILE, 'utf8'));
  return { requestsData, metricsData };
}

/**
 * Calculate daily metrics
 */
function calculateDailyMetrics(requestsData, metricsData) {
  const today = getTodayDateCST();
  
  // Filter requests from today
  const todayRequests = requestsData.requests.filter(req => {
    const reqDate = timestampToDateCST(req.timestamp);
    return reqDate === today;
  });

  if (todayRequests.length === 0) {
    console.warn(`⚠️  No requests found for today (${today})`);
    return null;
  }

  // Calculate totals
  const totalRequests = todayRequests.length;
  const totalCost = todayRequests.reduce((sum, req) => sum + (req.total_cost_usd || 0), 0);

  // Calculate classification percentages
  const classificationCounts = {
    LOCAL_VIABLE: 0,
    NEEDS_CLAUDE: 0,
    EDGE_CASE: 0
  };

  todayRequests.forEach(req => {
    if (req.classification && classificationCounts.hasOwnProperty(req.classification)) {
      classificationCounts[req.classification]++;
    }
  });

  const pctLocalViable = ((classificationCounts.LOCAL_VIABLE / totalRequests) * 100).toFixed(1);
  const pctNeedsClaude = ((classificationCounts.NEEDS_CLAUDE / totalRequests) * 100).toFixed(1);
  const pctEdgeCase = ((classificationCounts.EDGE_CASE / totalRequests) * 100).toFixed(1);

  // Top agent by cost
  const agentCosts = {};
  todayRequests.forEach(req => {
    if (!agentCosts[req.agent_name]) {
      agentCosts[req.agent_name] = 0;
    }
    agentCosts[req.agent_name] += req.total_cost_usd || 0;
  });

  let topAgent = null;
  let topCost = 0;
  for (const [agent, cost] of Object.entries(agentCosts)) {
    if (cost > topCost) {
      topCost = cost;
      topAgent = agent;
    }
  }

  // Monthly projection
  const monthlyProjection = (totalCost * 30).toFixed(2);

  return {
    date: today,
    totalRequests,
    totalCost: totalCost.toFixed(2),
    pctLocalViable,
    pctNeedsClaude,
    pctEdgeCase,
    topAgent: topAgent || 'N/A',
    topAgentCost: topCost.toFixed(2),
    monthlyProjection
  };
}

/**
 * Update Google Sheet using mcporter
 * 
 * Note: Make sure your Google Sheet has these columns:
 * A: Date
 * B: Total Requests
 * C: Total Cost
 * D: % Local Viable
 * E: % Needs Claude
 * F: % Edge Case
 * G: Top Agent (+ Cost)
 * H: Monthly Projection
 */
async function updateGoogleSheet(metrics) {
  if (!metrics) {
    console.error('❌ No metrics to export');
    return false;
  }

  // Prepare row values
  const values = [
    metrics.date,
    metrics.totalRequests,
    metrics.totalCost,
    metrics.pctLocalViable,
    metrics.pctNeedsClaude,
    metrics.pctEdgeCase,
    `${metrics.topAgent} ($${metrics.topAgentCost})`,
    metrics.monthlyProjection
  ];

  console.log('📊 Daily metrics:');
  console.log(`  Date: ${metrics.date}`);
  console.log(`  Total Requests: ${metrics.totalRequests}`);
  console.log(`  Total Cost: $${metrics.totalCost}`);
  console.log(`  Classification: ${metrics.pctLocalViable}% LOCAL_VIABLE, ${metrics.pctNeedsClaude}% NEEDS_CLAUDE, ${metrics.pctEdgeCase}% EDGE_CASE`);
  console.log(`  Top Agent: ${metrics.topAgent} ($${metrics.topAgentCost})`);
  console.log(`  Monthly Projection: $${metrics.monthlyProjection}`);

  try {
    // Call mcporter to append row to sheet
    const cmd = `${MCPORTER_BIN} call google-workspace.sheets_append_rows '${JSON.stringify({
      spreadsheet_id: SHEET_ID,
      sheet_name: SHEET_NAME,
      values: [values]
    })}'`;

    console.log('\n📤 Uploading to Google Sheet...');
    const result = execSync(cmd, { encoding: 'utf8' });
    
    console.log('\n✅ Data uploaded successfully!');
    console.log('Sheet ID:', SHEET_ID);
    console.log('Sheet Name:', SHEET_NAME);
    console.log('Values appended:', values);
    
    return true;
  } catch (error) {
    console.error('❌ Error uploading to Google Sheet:');
    console.error(error.message);
    
    // Try alternative method with sheets_write_range
    try {
      console.log('\n🔄 Trying alternative method...');
      const altCmd = `${MCPORTER_BIN} call google-workspace.sheets_write_range '${JSON.stringify({
        spreadsheet_id: SHEET_ID,
        sheet_name: SHEET_NAME,
        range: 'A:H',
        values: [values]
      })}'`;
      
      const altResult = execSync(altCmd, { encoding: 'utf8' });
      console.log('✅ Data written successfully with alternative method!');
      return true;
    } catch (altError) {
      console.error('❌ Alternative method also failed:');
      console.error(altError.message);
      console.error('\nTroubleshooting:');
      console.error('1. Verify GOOGLE_SHEETS_ID is set correctly');
      console.error('2. Check that mcporter is installed and configured');
      console.error('3. Ensure Google Sheet has columns A-H');
      console.error('4. Verify Google Workspace credentials are valid');
      return false;
    }
  }
}

/**
 * Main function
 */
async function main() {
  try {
    console.log('🚀 Starting daily metrics export...\n');

    // Load data
    console.log('📂 Loading data files...');
    const { requestsData, metricsData } = loadData();
    console.log(`✓ Loaded ${requestsData.requests.length} requests`);

    // Calculate metrics
    console.log('\n📈 Calculating daily metrics...');
    const metrics = calculateDailyMetrics(requestsData, metricsData);

    if (!metrics) {
      console.error('❌ Failed to calculate metrics');
      process.exit(1);
    }

    // Update Google Sheet
    console.log('\n');
    const success = await updateGoogleSheet(metrics);

    if (success) {
      console.log('\n✅ Daily export completed successfully!');
      process.exit(0);
    } else {
      console.log('\n⚠️  Export had issues. Check logs and Google Sheet manually.');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    process.exit(1);
  }
}

// Export for testing
module.exports = {
  getTodayDateCST,
  timestampToDateCST,
  loadData,
  calculateDailyMetrics,
  updateGoogleSheet
};

// Run if invoked directly
if (require.main === module) {
  main();
}
