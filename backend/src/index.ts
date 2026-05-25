import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import auth from './routes/auth.js'
import pair from './routes/pair.js'
import partner from './routes/partner.js'
import deviceToken from './routes/deviceToken.js'
import { startPoller } from './jobs/poller.js'

const app = new Hono()

app.get('/', (c) => c.json({ status: 'ok' }))
app.route('/auth', auth)
app.route('/pair', pair)
app.route('/', partner)
app.route('/', deviceToken)

if (process.env.NODE_ENV !== 'test') {
  serve({ fetch: app.fetch, port: 3000 }, (info) => {
    console.log(`tuneLink backend running on http://localhost:${info.port}`)
  })
  startPoller()
}

export default app
