import apn from '@parse/node-apn'
import { existsSync } from 'fs'

let provider: apn.Provider | null = null

function getProvider(): apn.Provider | null {
  if (provider) return provider

  const keyPath = process.env.APNS_KEY_PATH
  const keyId = process.env.APNS_KEY_ID
  const teamId = process.env.APNS_TEAM_ID

  if (!keyPath || !keyId || !teamId || !existsSync(keyPath)) return null

  provider = new apn.Provider({
    token: { key: keyPath, keyId, teamId },
    production: process.env.NODE_ENV === 'production',
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

  await p.send(note, deviceToken)
}
