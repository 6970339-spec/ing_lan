import { describe,it,expect } from 'vitest';
import { validateEnvelope } from './validate';
const base = {message_id:'1',topic:'chat.user.message',schema_version:1,correlation_id:'b1',producer:'web',ts:new Date().toISOString(),payload:{}};
describe('validate',()=>{
it('accepts valid',()=> expect(validateEnvelope(base)).toBeTruthy());
it('rejects missing topic',()=> expect(()=>validateEnvelope({...base,topic:undefined})).toThrow());
it('rejects schema version',()=> expect(()=>validateEnvelope({...base,schema_version:2})).toThrow());
it('accepts artifact refs',()=> expect(validateEnvelope({...base,artifact_refs:[{uri:'u',sha256:'s',mime:'m'}]})).toBeTruthy());
it('accepts causation id',()=> expect(validateEnvelope({...base,causation_id:'x'})).toBeTruthy());
it('rejects bad artifact ref',()=> expect(()=>validateEnvelope({...base,artifact_refs:[{uri:'u'}]})).toThrow());
});
