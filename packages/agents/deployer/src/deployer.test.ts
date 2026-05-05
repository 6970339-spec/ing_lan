import { describe,it,expect } from 'vitest';
import { agentName } from './index';
describe('deployer',()=>it('name',()=>expect(agentName).toBe('deployer')));
