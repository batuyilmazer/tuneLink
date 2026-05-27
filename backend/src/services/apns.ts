import apn from '@parse/node-apn'
import { existsSync } from 'fs'

let provider: apn.Provider | null = null

function getProvider(): apn.Provider | null {
  if (provider) return provider

  const keyPath = process.env.APNS_KEY_PATH
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID

  if (!keyPath || !keyId || !teamId || !existsSync(keyPath)) return null

  // Match the aps-environment in the iOS entitlements (development vs production).
  // Use APNS_PRODUCTION=true to switch to the production APNs endpoint.
  const production = process.env.APNS_PRODUCTION === 'true'

  provider = new apn.Provider({
    token: { key: keyPath, keyId, teamId },
    production,
  })

  return provider
}

export async function sendSilentPush(deviceToken: string, bundleId: string): Promise<void> {
  const p = getProvider()
  if (!p) return

  const note = new apn.Notification()
  note.contentAvailable = true
  note.pushType = 'background'
  note.priority = 5
  note.topic = bundleId
  note.expiry = Math.floor(Date.now() / 1000) + 60

  const result = await p.send(note, deviceToken)
  if (result.failed.length > 0) {
    console.error('[APNs] push failed:', JSON.stringify(result.failed))
  }
}
