import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import auth from './routes/auth.js'
import group from './routes/group.js'
import deviceToken from './routes/deviceToken.js'
import debug from './routes/debug.js'
import { startPoller } from './jobs/poller.js'

const app = new Hono()

app.get('/', (c) => c.json({ status: 'ok' }))
app.route('/auth', auth)
app.route('/', group)
app.route('/', deviceToken)
app.route('/', debug)

if (process.env.NODE_ENV !== 'test') {
  const port = Number(process.env.PORT) || 4002
  serve({ fetch: app.fetch, port }, (info) => {
    console.log(`tuneLink backend running on http://localhost:${info.port}`)
  })
  startPoller()
}

export default app
