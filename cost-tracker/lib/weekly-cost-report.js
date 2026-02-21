#!/usr/bin/env node
/**
 * Weekly Cost Report Generator
 * Runs every Sunday at 08:00 (adjust schedule in cron or systemd timer)
 * Generates JSON summary and optional notification
 */

const fs = require('fs').promises;
const path = require('path');
const { getMetrics, getRequests } = require('./api-cost-tracker');

const DATA_DIR = path.join(__dirname, '../data');
const REPORTS_DIR = path.join(DATA_DIR, 'weekly-reports');

/**
 * Format numbers as currency
 */
function formatCurrency(value) {
    return `$${value.toFixed(2)}`;
}

/**
 * Format as percentage
 */
function formatPercent(value) {
    return `${Math.round(value)}%`;
}

/**
 * Generate comprehensive weekly report
 */
async function generateWeeklyReport() {
    try {
        // Ensure reports directory exists
        await fs.mkdir(REPORTS_DIR, { recursive: true });

        // Get metrics for the week
        const metrics = await getMetrics('week');
        
        // Get all requests for detailed analysis
        const allRequests = await getRequests({ days: 7, limit: 10000 });
        
        // Generate week identifier
        const now = new Date();
        const weekStart = new Date(now);
        weekStart.setDate(now.getDate() - now.getDay() + 1); // Monday
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekStart.getDate() + 6); // Sunday
        
        const weekId = weekStart.toISOString().split('T')[0];
        const weekLabel = `Week of ${weekStart.toISOString().split('T')[0]}`;

        // Build comprehensive report
        const report = {
            metadata: {
                generated_at: new Date().toISOString(),
                week_id: weekId,
                week_label: weekLabel,
                period: `${weekStart.toISOString().split('T')[0]} → ${weekEnd.toISOString().split('T')[0]}`
            },
            summary: {
                total_requests: metrics.summary.total_requests,
                total_cost_usd: metrics.summary.total_cost,
                avg_cost_per_request: metrics.summary.avg_cost_per_request,
                avg_input_tokens: metrics.summary.avg_input_tokens,
                avg_output_tokens: metrics.summary.avg_output_tokens
            },
            classifications: metrics.classification_breakdown,
            top_agents: Object.entries(metrics.by_agent)
                .sort(([, a], [, b]) => b.cost - a.cost)
                .slice(0, 10)
                .map(([name, data]) => ({ agent: name, ...data })),
            top_models: Object.entries(metrics.by_model)
                .sort(([, a], [, b]) => b.cost - a.cost)
                .map(([model, data]) => ({ model, ...data })),
            projection: metrics.projection,
            recommendations: generateRecommendations(metrics, allRequests),
            requests_by_hour: groupRequestsByHour(allRequests.requests || [])
        };

        // Save report
        const reportPath = path.join(REPORTS_DIR, `${weekId}.json`);
        await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

        // Also update latest report
        const latestPath = path.join(REPORTS_DIR, 'latest.json');
        await fs.writeFile(latestPath, JSON.stringify(report, null, 2));

        // Generate text version for display/notification
        const textReport = formatTextReport(report);

        // Save text version
        const textPath = path.join(REPORTS_DIR, `${weekId}.txt`);
        await fs.writeFile(textPath, textReport);

        console.log(`✅ Weekly report generated: ${reportPath}`);
        console.log(textReport);

        return report;
    } catch (error) {
        console.error('❌ Error generating weekly report:', error.message);
        throw error;
    }
}

/**
 * Generate recommendations based on data analysis
 */
function generateRecommendations(metrics, allRequests) {
    const recommendations = [];
    const classifications = metrics.classification_breakdown;
    const localViable = classifications['LOCAL_VIABLE'] || {};
    const edgeCase = classifications['EDGE_CASE'] || {};

    // Recommendation 1: Local viable percentage
    if (localViable.percentage >= 50) {
        recommendations.push({
            priority: 'HIGH',
            type: 'optimization',
            title: 'High LOCAL_VIABLE percentage',
            description: `${localViable.percentage}% of requests are eligible for local model execution`,
            action: 'Evaluate migration strategy to reduce Claude API costs',
            estimated_impact: `Potential $${(localViable.total_cost * 12).toFixed(2)}/year savings`
        });
    }

    // Recommendation 2: Edge cases
    if (edgeCase.count > 20) {
        recommendations.push({
            priority: 'MEDIUM',
            type: 'review',
            title: `${edgeCase.count} EDGE_CASE requests need review`,
            description: 'Requests that are ambiguous between LOCAL_VIABLE and NEEDS_CLAUDE',
            action: 'Manually review sample of EDGE_CASE requests to refine classification rules',
            estimated_impact: `Potential to reclassify up to ${Math.round(edgeCase.count * 0.3)} additional requests`
        });
    }

    // Recommendation 3: Cost trend
    const totalCost = metrics.summary.total_cost;
    const projectedMonthly = totalCost * (30 / 7);
    if (projectedMonthly > 180) {
        recommendations.push({
            priority: 'HIGH',
            type: 'cost_trend',
            title: 'High weekly cost trend',
            description: `Current trajectory: ${formatCurrency(projectedMonthly)}/month`,
            action: 'Prioritize LOCAL_VIABLE migration to optimize costs',
            estimated_impact: `May require ${formatCurrency(projectedMonthly - 150)}/month optimization`
        });
    }

    // Recommendation 4: Agent efficiency
    const agentCosts = Object.entries(metrics.by_agent)
        .sort(([, a], [, b]) => b.cost - a.cost);
    
    if (agentCosts.length > 0 && agentCosts[0][1].cost > metrics.summary.total_cost * 0.4) {
        const [topAgent, topAgentData] = agentCosts[0];
        recommendations.push({
            priority: 'MEDIUM',
            type: 'agent_efficiency',
            title: `High concentration: ${topAgent} agent`,
            description: `${topAgent} accounts for ${(100 * topAgentData.cost / metrics.summary.total_cost).toFixed(1)}% of total cost`,
            action: `Review ${topAgent} request patterns and optimization opportunities`,
            estimated_impact: 'Potential for targeted cost reduction'
        });
    }

    return recommendations;
}

/**
 * Group requests by hour for trend analysis
 */
function groupRequestsByHour(requests) {
    const byHour = {};

    requests.forEach(req => {
        const date = new Date(req.timestamp);
        const hour = date.getHours();
        const key = `${hour.toString().padStart(2, '0')}:00`;

        if (!byHour[key]) {
            byHour[key] = { count: 0, cost: 0, classifications: {} };
        }

        byHour[key].count++;
        byHour[key].cost += req.total_cost_usd || 0;
        
        const cls = req.classification || 'UNKNOWN';
        byHour[key].classifications[cls] = (byHour[key].classifications[cls] || 0) + 1;
    });

    return byHour;
}

/**
 * Format report as readable text for display/notifications
 */
function formatTextReport(report) {
    const m = report.metadata;
    const s = report.summary;
    const c = report.classifications;
    const p = report.projection;
    const r = report.recommendations;

    let text = '';

    text += `📊 WEEKLY COST REPORT\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `Period: ${m.period}\n`;
    text += `Generated: ${new Date(m.generated_at).toLocaleString()}\n\n`;

    text += `📈 SUMMARY\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `Total Requests: ${s.total_requests}\n`;
    text += `Total Cost: ${formatCurrency(s.total_cost_usd)}\n`;
    text += `Avg/Request: ${formatCurrency(s.avg_cost_per_request)}\n`;
    text += `Avg Input: ${s.avg_input_tokens} tokens\n`;
    text += `Avg Output: ${s.avg_output_tokens} tokens\n\n`;

    text += `🏷️ CLASSIFICATION BREAKDOWN\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    Object.entries(c).forEach(([key, stats]) => {
        text += `${key.replace(/_/g, ' ')}: ${stats.count} requests (${formatPercent(stats.percentage)})\n`;
        text += `  └─ Cost: ${formatCurrency(stats.total_cost)}\n`;
        if (stats.potential_savings > 0) {
            text += `  └─ Potential Savings: ${formatCurrency(stats.potential_savings)}\n`;
        }
    });
    text += '\n';

    text += `🤖 TOP AGENTS\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    report.top_agents.slice(0, 5).forEach((agent, i) => {
        text += `${i + 1}. ${agent.agent} - ${formatCurrency(agent.cost)} (${agent.count} requests)\n`;
    });
    text += '\n';

    text += `💾 MODEL USAGE\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    report.top_models.forEach(m => {
        text += `${m.model}: ${m.count} requests (${formatPercent(m.percentage)}) - ${formatCurrency(m.cost)}\n`;
    });
    text += '\n';

    text += `🎯 M4 PRO PROJECTION\n`;
    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `M4 Pro Monthly Cost: ${formatCurrency(p.m4_pro_monthly_cost)}\n`;
    text += `Current Estimate: ${formatCurrency(p.current_monthly_estimate)}\n`;
    text += `Potential Savings: ${formatCurrency(p.potential_savings_monthly)}\n`;
    text += `ROI: ${p.roi}\n\n`;

    if (r && r.length > 0) {
        text += `💡 RECOMMENDATIONS\n`;
        text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
        r.forEach((rec, i) => {
            text += `${i + 1}. [${rec.priority}] ${rec.title}\n`;
            text += `   ${rec.description}\n`;
            text += `   Action: ${rec.action}\n`;
            text += `   Impact: ${rec.estimated_impact}\n\n`;
        });
    }

    text += `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    text += `Dashboard: http://YOUR_PI_IP:8080/cost-tracker-dashboard.html\n`;

    return text;
}

// Main execution
if (require.main === module) {
    generateWeeklyReport()
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
}

module.exports = { generateWeeklyReport, formatTextReport };
