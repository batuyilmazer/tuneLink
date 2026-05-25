import { Hono } from 'hono'
import { exchangeCode } from '../services/spotify.js'
import { setTokens, setUserDisplayName } from '../services/redis.js'

const auth = new Hono()

auth.post('/callback', async (c) => {
  const { code, code_verifier } = await c.req.json<{ code: string; code_verifier: string }>()

  if (!code || !code_verifier) {
    return c.json({ error: 'code and code_verifier are required' }, 400)
  }

  const { userId, displayName, access_token, refresh_token } = await exchangeCode(code, code_verifier)
  await setTokens(userId, { access_token, refresh_token })
  if (displayName) await setUserDisplayName(userId, displayName)

  return c.json({ userId })
})

export default auth
