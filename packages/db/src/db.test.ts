import { it,expect } from 'vitest'; import { dbNote } from './index'; it('db',()=>expect(dbNote.length).toBeGreaterThan(0));
