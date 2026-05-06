import { describe,it,expect } from 'vitest';
import { SCHEMA_VERSION } from './index';
describe('shared',()=>{it('schema version',()=>{expect(SCHEMA_VERSION).toBe(1);});});
