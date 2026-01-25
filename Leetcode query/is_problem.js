/**
 * Final Fixed Version (2026 Compatible)
 * Time Complexity: O(P + U * S) 
 * P = Total problems in LeetCode (~3000), U = Users, S = Submissions
 * Space Complexity: O(P)
 */

async function getSlugFromId(problemId) {
    // This endpoint returns all problems in a simple JSON format
    const url = 'https://leetcode.com/api/problems/all/';

    try {
        const response = await fetch(url);
        const data = await response.json();
        
        // Searching through the problem pairs
        const problem = data.stat_status_pairs.find(
            p => p.stat.frontend_question_id.toString() === problemId.toString()
        );

        if (problem) {
            return problem.stat.question__title_slug;
        }
        return null;
    } catch (err) {
        console.error("❌ Legacy API Error:", err.message);
        return null;
    }
}

async function checkUser(username, slug) {
    const query = `
    query userPublicProfile($username: String!) {
        recentAcSubmissionList(username: $username, limit: 1000) {
            titleSlug
        }
    }`;

    try {
        const response = await fetch('https://leetcode.com/graphql', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query, variables: { username } }),
        });
        const json = await response.json();
        const submissions = json.data?.recentAcSubmissionList || [];
        
        // Check if slug exists in the solved list
        const solved = submissions.some(s => s.titleSlug === slug);
        return { username, solved };
    } catch (err) {
        return { username, error: true };
    }
}

async function main() {
    const probId = process.argv[2];

    if (!probId) {
        console.log("❌ Usage: node is_problem.js 215");
        return;
    }

    console.log(`📡 Fetching Slug for Problem ID: ${probId} from LeetCode...`);
    const slug = await getSlugFromId(probId);

    if (!slug) {
        console.log(`❌ Error: Problem ID ${probId} not found.`);
        return;
    }

    const users = ['sojibrd', 'monadwizard', 'rabbihasan'];
    console.log(`🎯 Found Slug: ${slug}\n🔍 Checking users...\n`);

    const results = await Promise.all(users.map(u => checkUser(u, slug)));

    console.table(results.map(r => ({
        User: r.username.substring(3,5),
        Status: r.error ? '⚠️ Error' : (r.solved ? '✅ Solved' : '❌ Not Solved')
    })));
}

// Execution with error handling for comments (Step 15 requirement)
main().catch(err => console.error("Critical Error:", err));