import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import {
  fixPrompt,
  gateFixRun,
  gateFromCi,
  GATE_FIX_SIGNALS,
  inBash,
  runGateFix,
} from './run-gate.ts';

const CI = `
name: CI
on: [push, pull_request]
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - run: echo not the gate
  gate:
    name: Format, test and lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - name: Install
        run: npm ci
      - run: |
          npm run lint
          npm test
      - name: Only on main
        if: github.ref == 'refs/heads/main'
        run: npm run deploy-check
      - name: Needs a GitHub expression
        run: echo \${{ github.sha }}
      - name: In a folder, with env
        working-directory: web
        env:
          CI: 'true'
          NAME: it's
        run: npm run build
`;

test('a gate job in ci.yml becomes the gate: its run steps, in order', () => {
  const { steps } = gateFromCi(CI);
  assert.deepEqual(
    steps.map((s) => s.command),
    [
      'npm ci',
      'npm run lint\nnpm test',
      "cd 'web' && export CI='true' NAME='it'\\''s' && npm run build",
    ]
  );
  assert.equal(steps[0]!.name, 'Install');
});

test('steps that cannot be run faithfully are skipped, and the notes say which', () => {
  const { notes } = gateFromCi(CI);
  const text = notes.join('\n');
  assert.match(text, /Only on main/);
  assert.match(text, /Needs a GitHub expression/);
  assert.doesNotMatch(text, /actions\/checkout/);
});

test('a job called checks is the gate when there is no gate job', () => {
  const { steps } = gateFromCi('jobs:\n  checks:\n    steps:\n      - run: make check\n');
  assert.deepEqual(
    steps.map((s) => s.command),
    ['make check']
  );
});

test('no ci.yml: the gate runs nothing, and says so', () => {
  const { steps, notes } = gateFromCi(null);
  assert.deepEqual(steps, []);
  assert.match(notes.join('\n'), /no \.github\/workflows\/ci\.yml/i);
  assert.match(notes.join('\n'), /nothing/i);
});

test('a ci.yml with no gate job runs nothing, and says why', () => {
  const { steps, notes } = gateFromCi('jobs:\n  lint:\n    steps:\n      - run: x\n');
  assert.deepEqual(steps, []);
  assert.match(notes.join('\n'), /no `gate` or `checks` job/);
});

test('a gate job with no runnable step runs nothing, and says so', () => {
  const { steps, notes } = gateFromCi(
    'jobs:\n  gate:\n    steps:\n      - uses: actions/checkout@v4\n'
  );
  assert.deepEqual(steps, []);
  assert.match(notes.join('\n'), /no runnable step/);
});

test('a ci.yml that is not valid YAML is an error, not a silent empty gate', () => {
  assert.throws(() => gateFromCi('jobs: [unclosed'));
});

test('a GitHub expression in env or working-directory skips the step too', () => {
  const { steps, notes } = gateFromCi(
    'jobs:\n  gate:\n    steps:\n      - name: Secretive\n        env:\n          T: ${{ secrets.T }}\n        run: make\n'
  );
  assert.deepEqual(steps, []);
  assert.match(notes.join('\n'), /Secretive/);
});

test('the expression note names the expression syntax literally', () => {
  const { notes } = gateFromCi('jobs:\n  gate:\n    steps:\n      - run: echo ${{ x }}\n');
  assert.match(notes.join('\n'), /a \$\{\{ \}\} expression/);
});

// The sandbox runs a command with `sh`, so that is how these run it.
const sh = (command: string) => spawnSync('sh', ['-c', command], { encoding: 'utf8' });

test('a step runs under sh, which has no pipefail of its own', () => {
  const ran = sh(inBash("echo 'it''s' fine"));
  assert.equal(ran.status, 0, ran.stderr);
  assert.equal(ran.stdout, 'its fine\n');
});

test('a step fails when any command in a pipe fails, or any line of it does', () => {
  assert.notEqual(sh(inBash('false | true')).status, 0);
  assert.equal(sh(inBash('false\necho reached')).stdout, '');
});

const FAILURE = { step: 'Tests', command: 'tests/run', exitCode: 1, output: 'not ok 3' };

/** A fix attempt whose sessions answer with `signals`, in order. Records what happened. */
async function fixAttempt(signals: (string | undefined)[], maxSessions = signals.length) {
  const log: string[] = [];
  const sessions = await runGateFix({
    maxSessions,
    session: async (n) => {
      log.push(`session ${n}`);
      return { completionSignal: signals[n - 1] };
    },
    push: async (n) => {
      log.push(`push ${n}`);
    },
  });
  return { sessions, log };
}

test('a gate-fix session that signals completion is the last one of its attempt', async () => {
  const { sessions, log } = await fixAttempt([GATE_FIX_SIGNALS.complete, GATE_FIX_SIGNALS.complete]);
  assert.equal(sessions, 1);
  assert.deepEqual(log, ['session 1', 'push 1']);
});

test('a gate-fix session that says it is blocked ends the attempt too', async () => {
  const { log } = await fixAttempt([GATE_FIX_SIGNALS.blocked, undefined]);
  assert.deepEqual(log, ['session 1', 'push 1']);
});

test('a session that ends without a signal is followed by another, up to the limit', async () => {
  const { sessions, log } = await fixAttempt([undefined, undefined, undefined, undefined], 3);
  assert.equal(sessions, 3);
  assert.deepEqual(log, ['session 1', 'push 1', 'session 2', 'push 2', 'session 3', 'push 3']);
});

test('every gate-fix session is pushed before the next one starts', async () => {
  const { log } = await fixAttempt([undefined, GATE_FIX_SIGNALS.complete]);
  assert.deepEqual(log, ['session 1', 'push 1', 'session 2', 'push 2']);
});

test('the fix prompt tells the agent how to say it is finished, fixed or already green', () => {
  const prompt = fixPrompt(FAILURE, 1, 2);
  for (const signal of Object.values(GATE_FIX_SIGNALS)) assert.ok(prompt.includes(signal), signal);
  assert.match(prompt, /already passes/);
});

test('a gate-fix session that throws is still pushed, and the error is not swallowed', async () => {
  const log: string[] = [];
  await assert.rejects(
    runGateFix({
      session: async () => {
        throw new Error('idle timeout');
      },
      push: async (n) => {
        log.push(`push ${n}`);
      },
    }),
    /idle timeout/
  );
  assert.deepEqual(log, ['push 1']);
});

test('a gate-fix session is one iteration that ends on either signal', () => {
  const run = gateFixRun(2, 1, 'the prompt');
  assert.equal(run.maxIterations, 1);
  assert.deepEqual(run.completionSignal, [GATE_FIX_SIGNALS.complete, GATE_FIX_SIGNALS.blocked]);
  assert.equal(run.name, 'gate-fix-2.1');
});
