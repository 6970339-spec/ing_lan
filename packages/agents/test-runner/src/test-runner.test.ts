import { describe,it,expect } from 'vitest';
import { agentName } from './index';
describe('test-runner',()=>it('name',()=>expect(agentName).toBe('test-runner')));
