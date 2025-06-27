# YODA Complete System Setup Script
# Run this in your YodaSystem directory

Write-Host "`n🚀 Setting up YODA Complete System..." -ForegroundColor Green

# Create directory structure
Write-Host "`n📁 Creating directory structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "worker/src"
New-Item -ItemType Directory -Force -Path "public"
New-Item -ItemType Directory -Force -Path ".github/workflows"

# Create README
Write-Host "📝 Creating README..." -ForegroundColor Cyan
@"
# 🤖 YODA System - Your Optimal Documentation Assistant

## Overview
Complete AI-powered clinical practice management system with:
- 🧠 AI Chat Interface
- ⚡ Task Automation
- 📊 Real-time Analytics
- 💾 Memory System
- 📱 Mobile PWA

## Quick Start
1. Deploy worker: ``cd worker && npm install && npx wrangler deploy``
2. Open ``index.html`` on your phone
3. Say "Hey YODA" or click ⚡ to automate!

## Features
- **49 Clients** managed
- **183 Total Sessions** tracked
- **263 Memories** stored  
- **131 Tasks** automated
- **Real-time sync** every 30 seconds

## Endpoints
- Worker API: https://yoda-mobile.michaelarobards.workers.dev
- Database IDs:
  - Clinical: 7ab6743b-2e63-474a-85d2-4e9dd59859ba
  - Memory: b79eba66-2f1d-4ac6-bec1-423385949c87

## Technologies
- Cloudflare Workers (Backend)
- D1 Databases (Storage)
- Vanilla JS (Frontend)
- Matrix CSS Theme
"@ | Out-File -FilePath "README.md" -Encoding UTF8

# Create Worker
Write-Host "🛠️  Creating Worker..." -ForegroundColor Cyan
@'
// YODA Worker API with Full Integration
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // CORS headers
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Content-Type': 'application/json'
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    try {
      const path = url.pathname;

      // Status endpoint
      if (path === '/api/status') {
        const [clinicalInfo, memoryInfo, pendingTasks, todayRevenue] = await Promise.all([
          env.CLINICAL_DB.prepare('SELECT COUNT(*) as count FROM clients').first(),
          env.MEMORY_DB.prepare('SELECT COUNT(*) as count FROM memories').first(),
          env.CLINICAL_DB.prepare('SELECT COUNT(*) as count FROM tasks WHERE status = "pending"').first(),
          env.CLINICAL_DB.prepare(`
            SELECT SUM(actual_minutes * 3.75) as revenue
            FROM tasks
            WHERE status = 'completed' 
            AND date(completed_at) = date('now')
          `).first()
        ]);

        return new Response(JSON.stringify({
          status: 'operational',
          version: '3.0.0',
          databases: {
            clinical: clinicalInfo?.count || 0,
            memory: memoryInfo?.count || 0
          },
          pendingTasks: pendingTasks?.count || 0,
          todayRevenue: todayRevenue?.revenue || 0,
          timestamp: new Date().toISOString()
        }), { headers });
      }

      // AI Query endpoint
      if (path === '/api/ai/query' && request.method === 'POST') {
        const { query } = await request.json();
        const lowerQuery = query.toLowerCase();
        
        let response = '';
        let data = {};

        if (lowerQuery.includes('client')) {
          const clients = await env.CLINICAL_DB.prepare(`
            SELECT * FROM clients ORDER BY full_name LIMIT 10
          `).all();
          
          data.clients = clients.results;
          response = `Found ${clients.results.length} clients.`;
        }
        else if (lowerQuery.includes('task')) {
          const tasks = await env.CLINICAL_DB.prepare(`
            SELECT t.*, c.full_name as client_name
            FROM tasks t
            LEFT JOIN clients c ON t.client_id = c.id
            WHERE t.status = 'pending'
            ORDER BY t.priority ASC
            LIMIT 20
          `).all();
          
          data.tasks = tasks.results;
          response = `You have ${tasks.results.length} pending tasks.`;
        }
        else if (lowerQuery.includes('automate')) {
          const autoTasks = await env.CLINICAL_DB.prepare(`
            SELECT id FROM tasks 
            WHERE status = 'pending' AND auto_completable = 1
            LIMIT 10
          `).all();
          
          let completed = 0;
          for (const task of autoTasks.results) {
            await env.CLINICAL_DB.prepare(`
              UPDATE tasks 
              SET status = 'completed', completed_at = datetime('now')
              WHERE id = ?
            `).bind(task.id).run();
            completed++;
          }
          
          response = `✅ Automated ${completed} tasks!`;
        }
        else {
          response = `I can help with: clients, tasks, revenue, automation.`;
        }

        return new Response(JSON.stringify({
          response,
          data,
          query,
          timestamp: new Date().toISOString()
        }), { headers });
      }

      // Clients endpoint
      if (path === '/api/clients') {
        const clients = await env.CLINICAL_DB.prepare(`
          SELECT c.*, COUNT(t.id) as pending_tasks
          FROM clients c
          LEFT JOIN tasks t ON c.id = t.client_id AND t.status = 'pending'
          GROUP BY c.id
          ORDER BY c.full_name
        `).all();

        return new Response(JSON.stringify(clients.results), { headers });
      }

      // Tasks endpoint
      if (path === '/api/tasks') {
        const tasks = await env.CLINICAL_DB.prepare(`
          SELECT t.*, c.full_name as client_name
          FROM tasks t
          LEFT JOIN clients c ON t.client_id = c.id
          WHERE t.status = 'pending'
          ORDER BY t.priority ASC, t.due_date ASC
        `).all();

        return new Response(JSON.stringify({
          tasks: tasks.results,
          stats: {
            total: tasks.results.length,
            auto_completable: tasks.results.filter(t => t.auto_completable).length
          }
        }), { headers });
      }

      // Auto-complete endpoint
      if (path === '/api/tasks/auto-complete' && request.method === 'POST') {
        const autoTasks = await env.CLINICAL_DB.prepare(`
          SELECT * FROM tasks 
          WHERE status = 'pending' AND auto_completable = 1
          LIMIT 50
        `).all();
        
        let completed = 0;
        let revenue = 0;
        
        for (const task of autoTasks.results) {
          await env.CLINICAL_DB.prepare(`
            UPDATE tasks 
            SET status = 'completed', 
                completed_at = datetime('now'),
                completed_by = 'YODA Auto',
                actual_minutes = estimated_minutes
            WHERE id = ?
          `).bind(task.id).run();
          
          completed++;
          revenue += (task.estimated_minutes || 60) * 3.75;
        }
        
        return new Response(JSON.stringify({
          success: true,
          completed,
          revenue,
          message: `Completed ${completed} tasks, generated $${revenue}!`
        }), { headers });
      }

      return new Response(JSON.stringify({ 
        error: 'Not found',
        available: ['/api/status', '/api/clients', '/api/tasks', '/api/ai/query']
      }), { status: 404, headers });

    } catch (error) {
      return new Response(JSON.stringify({ 
        error: 'Internal server error', 
        message: error.message 
      }), { status: 500, headers });
    }
  }
};
'@ | Out-File -FilePath "worker/src/index.js" -Encoding UTF8

# Create wrangler.toml
Write-Host "⚙️  Creating wrangler.toml..." -ForegroundColor Cyan
@"
name = "yoda-mobile"
main = "src/index.js"
compatibility_date = "2024-01-01"
account_id = "299311f7a0bb2b23f2a84cd36e67589d"

[env.production]
workers_dev = true

[[d1_databases]]
binding = "CLINICAL_DB"
database_name = "smart-clinical-workflow"
database_id = "7ab6743b-2e63-474a-85d2-4e9dd59859ba"

[[d1_databases]]
binding = "MEMORY_DB"
database_name = "michael_memory"
database_id = "b79eba66-2f1d-4ac6-bec1-423385949c87"
"@ | Out-File -FilePath "worker/wrangler.toml" -Encoding UTF8

# Create package.json for worker
Write-Host "📦 Creating package.json..." -ForegroundColor Cyan
@"
{
  "name": "yoda-worker",
  "version": "3.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "logs": "wrangler tail"
  },
  "devDependencies": {
    "wrangler": "^3.0.0"
  }
}
"@ | Out-File -FilePath "worker/package.json" -Encoding UTF8

# Create the main HTML file
Write-Host "📱 Creating index.html..." -ForegroundColor Cyan
@'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <title>YODA Matrix</title>
    <link rel="manifest" href="/manifest.json">
    <style>
        :root {
            --green: #00ff41;
            --black: #000000;
            --red: #ff0041;
            --yellow: #ffaa00;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            -webkit-tap-highlight-color: transparent;
        }

        body {
            font-family: 'Courier New', monospace;
            background: var(--black);
            color: var(--green);
            height: 100vh;
            overflow: hidden;
            position: fixed;
            width: 100%;
        }

        .app {
            height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .header {
            background: rgba(0, 0, 0, 0.95);
            border-bottom: 2px solid var(--green);
            padding: 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 1.5rem;
            font-weight: bold;
            text-shadow: 0 0 20px var(--green);
        }

        .main {
            flex: 1;
            overflow-y: auto;
            padding: 1rem;
            padding-bottom: 80px;
        }

        .metrics {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 1rem;
            margin-bottom: 2rem;
        }

        .metric-card {
            background: rgba(0, 255, 65, 0.1);
            border: 2px solid var(--green);
            border-radius: 8px;
            padding: 1.5rem;
            text-align: center;
            cursor: pointer;
        }

        .metric-card:active {
            transform: scale(0.98);
            background: rgba(0, 255, 65, 0.2);
        }

        .metric-value {
            font-size: 2.5rem;
            font-weight: bold;
            margin: 0.5rem 0;
            text-shadow: 0 0 10px var(--green);
        }

        .metric-label {
            font-size: 0.9rem;
            opacity: 0.8;
            text-transform: uppercase;
        }

        .nav {
            background: rgba(0, 0, 0, 0.95);
            border-top: 2px solid var(--green);
            display: flex;
            justify-content: space-around;
            padding: 1rem 0;
        }

        .nav-item {
            text-align: center;
            cursor: pointer;
            opacity: 0.6;
        }

        .nav-item.active {
            opacity: 1;
            color: var(--green);
            text-shadow: 0 0 10px var(--green);
        }

        .fab {
            position: fixed;
            bottom: 90px;
            right: 20px;
            width: 56px;
            height: 56px;
            background: var(--green);
            color: var(--black);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
            cursor: pointer;
            box-shadow: 0 4px 20px rgba(0, 255, 65, 0.5);
        }

        .fab:active {
            transform: scale(0.9);
        }

        .loading {
            text-align: center;
            padding: 2rem;
        }

        .task-item {
            background: rgba(0, 255, 65, 0.05);
            border: 1px solid var(--green);
            border-radius: 4px;
            padding: 1rem;
            margin-bottom: 0.5rem;
        }
    </style>
</head>
<body>
    <div class="app">
        <header class="header">
            <div class="logo">🤖 YODA</div>
            <div id="status">●</div>
        </header>
        
        <main class="main" id="mainContent">
            <div class="loading">Loading YODA system...</div>
        </main>
        
        <nav class="nav">
            <div class="nav-item active" onclick="showDashboard()">📊 Dashboard</div>
            <div class="nav-item" onclick="showTasks()">📋 Tasks</div>
            <div class="nav-item" onclick="showClients()">👥 Clients</div>
            <div class="nav-item" onclick="showAI()">🧠 AI</div>
        </nav>
        
        <div class="fab" onclick="runAutomation()">⚡</div>
    </div>

    <script>
        const API = 'https://yoda-mobile.michaelarobards.workers.dev';
        let currentView = 'dashboard';

        async function init() {
            await loadDashboard();
            setInterval(updateData, 30000);
        }

        async function loadDashboard() {
            try {
                const response = await fetch(API + '/api/status');
                const status = await response.json();
                
                document.getElementById('mainContent').innerHTML = `
                    <div class="metrics">
                        <div class="metric-card" onclick="showClients()">
                            <div class="metric-value">${status.databases?.clinical || 0}</div>
                            <div class="metric-label">Clients</div>
                        </div>
                        <div class="metric-card" onclick="showTasks()">
                            <div class="metric-value">${status.pendingTasks || 0}</div>
                            <div class="metric-label">Tasks</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">$${status.todayRevenue || 0}</div>
                            <div class="metric-label">Revenue</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value">${status.databases?.memory || 0}</div>
                            <div class="metric-label">Memories</div>
                        </div>
                    </div>
                    <div style="text-align: center; opacity: 0.7;">
                        <p>Last sync: ${new Date(status.timestamp).toLocaleTimeString()}</p>
                    </div>
                `;
            } catch (error) {
                console.error('Dashboard error:', error);
            }
        }

        async function showTasks() {
            currentView = 'tasks';
            updateNav();
            document.getElementById('mainContent').innerHTML = '<div class="loading">Loading tasks...</div>';
            
            try {
                const response = await fetch(API + '/api/tasks');
                const data = await response.json();
                
                const tasksHtml = data.tasks?.map(task => `
                    <div class="task-item">
                        <strong>${task.title}</strong><br>
                        <small>${task.client_name || 'General'} | Priority: ${task.priority}</small>
                    </div>
                `).join('') || '<p>No tasks found</p>';
                
                document.getElementById('mainContent').innerHTML = `
                    <h2>Tasks (${data.stats?.total || 0})</h2>
                    <p>Auto-completable: ${data.stats?.auto_completable || 0}</p>
                    ${tasksHtml}
                `;
            } catch (error) {
                console.error('Tasks error:', error);
            }
        }

        async function showClients() {
            currentView = 'clients';
            updateNav();
            document.getElementById('mainContent').innerHTML = '<div class="loading">Loading clients...</div>';
            
            try {
                const response = await fetch(API + '/api/clients');
                const clients = await response.json();
                
                const clientsHtml = clients?.map(client => `
                    <div class="task-item">
                        <strong>${client.full_name}</strong><br>
                        <small>Tasks: ${client.pending_tasks || 0}</small>
                    </div>
                `).join('') || '<p>No clients found</p>';
                
                document.getElementById('mainContent').innerHTML = `
                    <h2>Clients (${clients?.length || 0})</h2>
                    ${clientsHtml}
                `;
            } catch (error) {
                console.error('Clients error:', error);
            }
        }

        function showAI() {
            currentView = 'ai';
            updateNav();
            
            document.getElementById('mainContent').innerHTML = `
                <h2>AI Assistant</h2>
                <textarea id="aiQuery" style="width:100%; padding:1rem; background:rgba(0,255,65,0.1); 
                    border:1px solid var(--green); color:var(--green); font-family:inherit;" 
                    rows="3" placeholder="Ask YODA anything..."></textarea>
                <button onclick="askAI()" style="margin-top:1rem; padding:1rem 2rem; 
                    background:var(--green); color:var(--black); border:none; cursor:pointer;">
                    Ask YODA
                </button>
                <div id="aiResponse" style="margin-top:2rem;"></div>
            `;
        }

        async function askAI() {
            const query = document.getElementById('aiQuery').value;
            if (!query) return;
            
            document.getElementById('aiResponse').innerHTML = '<div class="loading">YODA is thinking...</div>';
            
            try {
                const response = await fetch(API + '/api/ai/query', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ query })
                });
                
                const result = await response.json();
                document.getElementById('aiResponse').innerHTML = `
                    <div class="task-item">
                        <strong>YODA says:</strong><br>
                        ${result.response}
                    </div>
                `;
            } catch (error) {
                console.error('AI error:', error);
            }
        }

        async function runAutomation() {
            const fab = document.querySelector('.fab');
            fab.style.transform = 'rotate(360deg)';
            
            try {
                const response = await fetch(API + '/api/tasks/auto-complete', {
                    method: 'POST'
                });
                const result = await response.json();
                
                alert(result.message || 'Automation complete!');
                loadDashboard();
            } catch (error) {
                console.error('Automation error:', error);
            }
            
            setTimeout(() => {
                fab.style.transform = '';
            }, 500);
        }

        function updateNav() {
            document.querySelectorAll('.nav-item').forEach(item => {
                item.classList.remove('active');
            });
        }

        async function updateData() {
            if (currentView === 'dashboard') {
                await loadDashboard();
            }
        }

        function showDashboard() {
            currentView = 'dashboard';
            loadDashboard();
            updateNav();
            document.querySelector('.nav-item').classList.add('active');
        }

        window.addEventListener('load', init);
    </script>
</body>
</html>
'@ | Out-File -FilePath "index.html" -Encoding UTF8

# Create manifest.json
Write-Host "📱 Creating manifest.json..." -ForegroundColor Cyan
@"
{
  "name": "YODA Matrix Mobile",
  "short_name": "YODA",
  "description": "Your Optimal Documentation Assistant",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#000000",
  "theme_color": "#00ff41",
  "orientation": "portrait",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
"@ | Out-File -FilePath "manifest.json" -Encoding UTF8

# Create service worker
Write-Host "🔧 Creating service worker..." -ForegroundColor Cyan
@"
const CACHE_NAME = 'yoda-v1';
const urlsToCache = ['/', '/index.html', '/manifest.json'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});
"@ | Out-File -FilePath "sw.js" -Encoding UTF8

# Create GitHub workflow
Write-Host "🔧 Creating GitHub workflow..." -ForegroundColor Cyan
@"
name: Deploy to Cloudflare

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy Worker
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: \${{ secrets.CLOUDFLARE_API_TOKEN }}
          workingDirectory: worker
          command: deploy --env production
          
      - name: Deploy Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: \${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: 299311f7a0bb2b23f2a84cd36e67589d
          projectName: yoda-matrix
          directory: .
          gitHubToken: \${{ secrets.GITHUB_TOKEN }}
"@ | Out-File -FilePath ".github/workflows/deploy.yml" -Encoding UTF8

# Create .gitignore
Write-Host "🚫 Creating .gitignore..." -ForegroundColor Cyan
@"
node_modules/
.wrangler/
.dev.vars
.env
dist/
.DS_Store
*.log
"@ | Out-File -FilePath ".gitignore" -Encoding UTF8

# Display summary
Write-Host "`n✅ YODA System created successfully!" -ForegroundColor Green
Write-Host "`nFiles created:" -ForegroundColor Cyan
Get-ChildItem -Recurse -File | ForEach-Object { Write-Host "  - $($_.FullName.Replace($PWD, '.'))" }

Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Commit and push to GitHub:" -ForegroundColor White
Write-Host "   git add ." -ForegroundColor Gray
Write-Host "   git commit -m 'YODA Complete System'" -ForegroundColor Gray
Write-Host "   git push -u origin main" -ForegroundColor Gray
Write-Host "`n2. Deploy the Worker:" -ForegroundColor White
Write-Host "   cd worker" -ForegroundColor Gray
Write-Host "   npm install" -ForegroundColor Gray
Write-Host "   npx wrangler deploy" -ForegroundColor Gray
Write-Host "`n3. Test your app:" -ForegroundColor White
Write-Host "   - Open index.html in your browser" -ForegroundColor Gray
Write-Host "   - Or deploy to Cloudflare Pages" -ForegroundColor Gray

Write-Host "`n🎉 Your YODA system is ready to deploy!" -ForegroundColor Green