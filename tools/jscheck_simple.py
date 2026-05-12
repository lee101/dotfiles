#!/usr/bin/env python3

import os
import subprocess
import sys
import tempfile
import textwrap


def check_js_errors(url):
    if not url.startswith(("http://", "https://")):
        url = "https://" + url

    script = textwrap.dedent(
        r"""
        const { chromium } = require('@playwright/test');

        (async () => {
          const url = process.argv[2];
          const executablePath = process.env.CHROME_BIN || '/usr/bin/google-chrome';
          const browser = await chromium.launch({
            headless: true,
            executablePath,
            args: ['--no-sandbox', '--disable-dev-shm-usage'],
          });
          const page = await browser.newPage();
          const errors = [];
          const failed = [];
          const ignoredHosts = [
            'googleads.g.doubleclick.net',
            'pagead2.googlesyndication.com',
            'securepubads.g.doubleclick.net',
          ];
          const ignored = (u) => {
            try {
              const parsed = new URL(u);
              return ignoredHosts.includes(parsed.hostname);
            } catch (_) {
              return false;
            }
          };

          page.on('console', (msg) => {
            if (msg.type() === 'error') {
              const text = msg.text();
              if (ignored(text)) return;
              const loc = msg.location();
              if (loc && loc.url && ignored(loc.url)) return;
              const where = loc && loc.url ? ` ${loc.url}:${loc.lineNumber || 0}` : '';
              errors.push(`${text}${where}`);
            }
          });
          page.on('response', (resp) => {
            if (resp.status() >= 400 && !ignored(resp.url())) {
              failed.push(`HTTP ${resp.status()} ${resp.request().method()} ${resp.url()}`);
            }
          });
          page.on('pageerror', (err) => {
            errors.push(err.stack || err.message || String(err));
          });
          page.on('requestfailed', (req) => {
            if (ignored(req.url())) return;
            failed.push(`${req.method()} ${req.url()} ${req.failure() ? req.failure().errorText : ''}`);
          });

          const started = Date.now();
          try {
            await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
            await page.waitForTimeout(3000);
          } finally {
            console.log(`Loaded ${url} in ${Date.now() - started}ms`);
            if (errors.length) {
              console.log(`Found ${errors.length} JavaScript errors:`);
              for (const err of errors) console.log(`[ERROR] ${err}`);
            } else {
              console.log('No JavaScript errors found');
            }
            if (failed.length) {
              console.log(`Found ${failed.length} failed/4xx requests:`);
              for (const req of failed.slice(0, 40)) console.log(`[REQUEST_FAILED] ${req}`);
            }
            await browser.close();
          }
          process.exit(errors.length ? 1 : 0);
        })().catch((err) => {
          console.error(err && (err.stack || err.message) || err);
          process.exit(2);
        });
        """
    )

    with tempfile.NamedTemporaryFile("w", suffix=".cjs", delete=False) as f:
        f.write(script)
        script_path = f.name

    try:
        env = os.environ.copy()
        env["NODE_PATH"] = os.pathsep.join(
            p
            for p in [
                os.path.join(os.getcwd(), "node_modules"),
                "/mnt/fast/code/netwrck/node_modules",
                env.get("NODE_PATH", ""),
            ]
            if p
        )
        return subprocess.call(["node", script_path, url], env=env)
    finally:
        try:
            os.unlink(script_path)
        except OSError:
            pass


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: jscheck_simple.py <url>")
        sys.exit(1)
    sys.exit(check_js_errors(sys.argv[1]))
