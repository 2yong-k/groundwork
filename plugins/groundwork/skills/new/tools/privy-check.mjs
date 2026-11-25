// Does a Privy wallet policy hold against the wallet's own user session? Prints outcomes only, never a key or token.
import { PrivyClient, generateP256KeyPair } from '@privy-io/node';

const { PRIVY_APP_ID: appId, PRIVY_APP_SECRET: appSecret, PRIVY_TEST_EMAIL: email, PRIVY_TEST_OTP: code } = process.env;
for (const [k, v] of Object.entries({ appId, appSecret, email, code })) if (!v) throw new Error(`missing ${k}`);

const ALLOWED = '0x1111111111111111111111111111111111111111';
const OTHER = '0x2222222222222222222222222222222222222222';
const privy = new PrivyClient({ appId, appSecret });

const attempt = async (label, fn) => {
  try {
    await fn();
    console.log(`SUCCEEDED  ${label}`);
    return true;
  } catch (e) {
    const status = e?.status ?? '-';
    const msg = String(e?.error?.error ?? e?.message ?? e).replace(/eyJ[\w.-]+/g, '<jwt>').slice(0, 150);
    console.log(`REFUSED    ${label} [${status}] ${msg}`);
    return false;
  }
};

async function login() {
  const headers = { 'content-type': 'application/json', 'privy-app-id': appId, 'privy-client': 'js-sdk-core:0.0.0', origin: 'http://localhost:3000' };
  const post = async (path, body) => {
    const r = await fetch(`https://auth.privy.io/api/v1${path}`, { method: 'POST', headers, body: JSON.stringify(body) });
    if (!r.ok) throw new Error(`${path} -> ${r.status} ${(await r.text()).slice(0, 150)}`);
    return r.json();
  };
  await post('/passwordless/init', { email });
  const { token, user } = await post('/passwordless/authenticate', { email, code });
  return { jwt: token, userId: user.id };
}

const signTx = (id, to, jwt) =>
  privy.wallets().ethereum().signTransaction(id, {
    params: { transaction: { to, value: '0x1', chain_id: 84532, type: 2, nonce: 0, gas_limit: '0x5208', max_fee_per_gas: '0x3b9aca00', max_priority_fee_per_gas: '0x3b9aca00' } },
    authorization_context: { user_jwts: [jwt] },
  });

const { jwt, userId } = await login();
console.log('login ok (test account)');

const policy = await privy.policies().create({
  name: 'new-skill policy check',
  version: '1.0',
  chain_type: 'ethereum',
  rules: [{
    name: 'Only the allowed address',
    method: 'eth_signTransaction',
    action: 'ALLOW',
    conditions: [{ field_source: 'ethereum_transaction', field: 'to', operator: 'eq', value: ALLOWED }],
  }, {
    name: 'No key export',
    method: 'exportPrivateKey',
    action: 'DENY',
    conditions: [],
  }],
});
console.log('policy created');

console.log('\n== A. user owns the wallet, policy on the wallet (the shape the skill recommends today)');
const a = await privy.wallets().create({ chain_type: 'ethereum', owner: { user_id: userId }, policy_ids: [policy.id] });
await attempt('A1 user session signs inside the policy', () => signTx(a.id, ALLOWED, jwt));
await attempt('A2 user session signs outside the policy', () => signTx(a.id, OTHER, jwt));
const lifted = await attempt('A3 user session removes the policy', () =>
  privy.wallets().update(a.id, { policy_ids: [], authorization_context: { user_jwts: [jwt] } }));
if (lifted) await attempt('A4 user session signs outside after removing it', () => signTx(a.id, OTHER, jwt));
// A fresh wallet, since A3 may have removed the policy. The key is dropped, never printed.
const a5 = await privy.wallets().create({ chain_type: 'ethereum', owner: { user_id: userId }, policy_ids: [policy.id] });
await attempt('A5 user session exports the private key', async () => {
  await privy.wallets().exportPrivateKey(a5.id, { authorization_context: { user_jwts: [jwt] } });
});

console.log('\n== B. owner is a 2-of-2 quorum (app key + user), the user signs as a signer under the policy');
const app = await generateP256KeyPair();
const owner = await privy.keyQuorums().create({ authorization_threshold: 2, public_keys: [app.publicKey], user_ids: [userId], display_name: 'app+user' });
const signer = await privy.keyQuorums().create({ authorization_threshold: 1, user_ids: [userId], display_name: 'user' });
const b = await privy.wallets().create({
  chain_type: 'ethereum',
  owner_id: owner.id,
  additional_signers: [{ signer_id: signer.id, override_policy_ids: [policy.id] }],
});
await attempt('B1 user session signs inside the policy', () => signTx(b.id, ALLOWED, jwt));
await attempt('B2 user session signs outside the policy', () => signTx(b.id, OTHER, jwt));
await attempt('B3 user session removes the signer policy', () =>
  privy.wallets().update(b.id, { additional_signers: [{ signer_id: signer.id, override_policy_ids: [] }], authorization_context: { user_jwts: [jwt] } }));
await attempt('B4 app key alone signs outside the policy', () =>
  privy.wallets().ethereum().signTransaction(b.id, {
    params: { transaction: { to: OTHER, value: '0x1', chain_id: 84532, type: 2, nonce: 0, gas_limit: '0x5208', max_fee_per_gas: '0x3b9aca00', max_priority_fee_per_gas: '0x3b9aca00' } },
    authorization_context: { authorization_private_keys: [app.privateKey] },
  }));
await attempt('B5 app key alone changes the wallet', () =>
  privy.wallets().update(b.id, { additional_signers: [], authorization_context: { authorization_private_keys: [app.privateKey] } }));
await attempt('B6 app key and user together change the wallet', () =>
  privy.wallets().update(b.id, { policy_ids: [], authorization_context: { authorization_private_keys: [app.privateKey], user_jwts: [jwt] } }));
await attempt('B7 user session alone exports the private key', async () => {
  await privy.wallets().exportPrivateKey(b.id, { authorization_context: { user_jwts: [jwt] } });
});
