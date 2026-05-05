import { describe,it,expect } from 'vitest';
import { agentName } from './index';
describe('sandbox-runner',()=>it('name',()=>expect(agentName).toBe('sandbox-runner')));
