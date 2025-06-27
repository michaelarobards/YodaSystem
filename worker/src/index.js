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
