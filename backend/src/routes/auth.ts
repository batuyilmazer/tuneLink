import { Hono } from 'hono'
import { randomUUID } from 'crypto'
import { exchangeCode } from '../services/spotify.js'
import { setTokens, setUserDisplayName, addUserToGroup, removeUserFromGroup, setSessionToken, getSessionToken } from '../services/redis.js'

const auth = new Hono()

auth.post('/callback', async (c) => {
  const { code, code_verifier } = await c.req.json<{ code: string; code_verifier: string }>()

  if (!code || !code_verifier) {
    return c.json({ error: 'code and code_verifier are required' }, 400)
  }

  try {
    const { userId, displayName, access_token, refresh_token } = await exchangeCode(code, code_verifier)
    const sessionToken = randomUUID()
    await setTokens(userId, { access_token, refresh_token })
    await setUserDisplayName(userId, displayName ?? userId)
    await setSessionToken(userId, sessionToken)
    await addUserToGroup(userId)
    return c.json({ userId, sessionToken })
  } catch (err) {
    console.error('[auth] exchangeCode failed:', err)
    const message = err instanceof Error ? err.message : 'Auth failed'
    return c.json({ error: message }, 500)
  }
})

auth.delete('/logout', async (c) => {
  const { userId } = await c.req.json<{ userId: string }>()
  if (!userId) return c.json({ error: 'userId is required' }, 400)

  const bearer = c.req.header('Authorization')?.replace(/^Bearer\s+/i, '')
  if (!bearer) return c.json({ error: 'Unauthorized' }, 401)

  const stored = await getSessionToken(userId)
  if (!stored || stored !== bearer) {
    return c.json({ error: 'Unauthorized' }, 401)
  }

  await removeUserFromGroup(userId)
  return c.json({ ok: true })
})

export default auth
