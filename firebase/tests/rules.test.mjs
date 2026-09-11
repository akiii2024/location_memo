import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { strict as assert } from 'node:assert';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

const projectId = 'demo-location-memo';
let testEnv;

const mapData = (sharedWith = []) => ({
  ownerId: 'owner',
  title: '公開テスト地図',
  memoCount: 1,
  sharedWith,
  updatedAt: new Date(),
});

const memoData = () => ({
  title: 'テストメモ',
  content: '内容',
  notes: null,
  imageUrls: [],
  audioUrl: null,
  syncId: 'memo-sync-id',
  updatedAt: new Date(),
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8180,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
    storage: {
      host: '127.0.0.1',
      port: 9299,
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users/owner/maps/map-1'),
      mapData(['shared']),
    );
  });
});

after(async () => {
  await testEnv.cleanup();
});

describe('Firestore rules', () => {
  test('owner can update a valid map, other identities cannot', async () => {
    const owner = testEnv.authenticatedContext('owner').firestore();
    const outsider = testEnv.authenticatedContext('outsider').firestore();
    const anonymous = testEnv.unauthenticatedContext().firestore();
    const mapRef = doc(owner, 'users/owner/maps/map-1');

    await assertSucceeds(setDoc(mapRef, mapData(['shared'])));
    await assertFails(
      setDoc(doc(outsider, 'users/owner/maps/map-1'), mapData(['shared'])),
    );
    await assertFails(getDoc(doc(anonymous, 'users/owner/maps/map-1')));
    await assertFails(setDoc(mapRef, {...mapData(), title: 'x'.repeat(201)}));
  });

  test('shared user can edit memos but cannot edit or delete the map', async () => {
    const shared = testEnv.authenticatedContext('shared').firestore();
    const memoRef = doc(shared, 'users/owner/maps/map-1/memos/memo-sync-id');

    await assertSucceeds(setDoc(memoRef, memoData()));
    await assertSucceeds(getDoc(memoRef));
    await assertFails(
      setDoc(doc(shared, 'users/owner/maps/map-1'), mapData(['shared'])),
    );
    await assertFails(deleteDoc(doc(shared, 'users/owner/maps/map-1')));
  });

  test('third party and unauthenticated users cannot read or write memos', async () => {
    for (const db of [
      testEnv.authenticatedContext('outsider').firestore(),
      testEnv.unauthenticatedContext().firestore(),
    ]) {
      const memoRef = doc(db, 'users/owner/maps/map-1/memos/memo-sync-id');
      await assertFails(getDoc(memoRef));
      await assertFails(setDoc(memoRef, memoData()));
    }
  });

  test('shared access is revoked immediately', async () => {
    const shared = testEnv.authenticatedContext('shared').firestore();
    await assertSucceeds(
      getDoc(doc(shared, 'users/owner/maps/map-1/memos/memo-sync-id')),
    );
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users/owner/maps/map-1'),
        mapData([]),
      );
    });
    await assertFails(
      getDoc(doc(shared, 'users/owner/maps/map-1/memos/memo-sync-id')),
    );
  });
});

describe('Storage rules', () => {
  test('owner can upload a valid base-map generation', async () => {
    const storage = testEnv.authenticatedContext('owner').storage();
    await assertSucceeds(
      uploadBytes(
        ref(storage, 'users/owner/maps/map-1/base_generations/gen/base.png'),
        new Uint8Array([1, 2, 3]),
        {contentType: 'image/png'},
      ),
    );
  });

  test('shared user can upload memo media but not a base map', async () => {
    const storage = testEnv.authenticatedContext('shared').storage();
    await assertSucceeds(
      uploadBytes(
        ref(storage, 'users/owner/maps/map-1/memos/memo-1/generations/gen/audio/memo.webm'),
        new Uint8Array([1, 2, 3]),
        {contentType: 'audio/webm'},
      ),
    );
    await assertFails(
      uploadBytes(
        ref(storage, 'users/owner/maps/map-1/base_generations/gen/base.png'),
        new Uint8Array([1]),
        {contentType: 'image/png'},
      ),
    );
  });

  test('invalid MIME, oversized files, outsiders and guests are rejected', async () => {
    const owner = testEnv.authenticatedContext('owner').storage();
    await assertFails(
      uploadBytes(
        ref(owner, 'users/owner/maps/map-1/memos/memo-1/generations/gen/images/file.txt'),
        new Uint8Array([1]),
        {contentType: 'text/plain'},
      ),
    );
    await assertFails(
      uploadBytes(
        ref(owner, 'users/owner/maps/map-1/memos/memo-1/generations/gen/images/too-large.png'),
        new Uint8Array(20 * 1024 * 1024 + 1),
        {contentType: 'image/png'},
      ),
    );
    await assertFails(
      uploadBytes(
        ref(owner, 'users/owner/maps/map-1/memos/memo-1/generations/gen/images/wrong.mp3'),
        new Uint8Array([1]),
        {contentType: 'audio/mpeg'},
      ),
    );
    await assertFails(
      uploadBytes(
        ref(owner, 'users/owner/maps/map-1/memos/memo-1/generations/gen/audio/wrong.png'),
        new Uint8Array([1]),
        {contentType: 'image/png'},
      ),
    );
    for (const storage of [
      testEnv.authenticatedContext('outsider').storage(),
      testEnv.unauthenticatedContext().storage(),
    ]) {
      await assertFails(
        uploadBytes(
          ref(storage, 'users/owner/maps/map-1/memos/memo-1/generations/gen/images/file.png'),
          new Uint8Array([1]),
          {contentType: 'image/png'},
        ),
      );
    }
  });
});

assert.ok(true);
