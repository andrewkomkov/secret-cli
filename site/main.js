(() => {
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  // Nav border after the first scroll.
  const nav = $(".nav");
  const onScroll = () => nav.classList.toggle("scrolled", scrollY > 8);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Light that follows the pointer.
  if (!reduce) {
    addEventListener("pointermove", (e) => {
      document.documentElement.style.setProperty("--mx", e.clientX + "px");
      document.documentElement.style.setProperty("--my", e.clientY + "px");
    }, { passive: true });
  }

  // Reveal on scroll, staggered inside one parent.
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      const sibs = $$(":scope > .reveal", e.target.parentElement);
      e.target.style.setProperty("--d", Math.max(0, sibs.indexOf(e.target)) * 0.08 + "s");
      e.target.classList.add("in");
      io.unobserve(e.target);
    }
  }, { threshold: 0.15, rootMargin: "0px 0px -40px 0px" });
  $$(".reveal").forEach((el) => io.observe(el));

  // Copy buttons.
  const toast = $("#toast");
  let toastTimer;
  const say = (t) => {
    toast.textContent = t;
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
  };
  $$(".install").forEach((box) => {
    const btn = $(".copy", box);
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(box.dataset.copy);
        btn.classList.add("done");
        say("Copied to the clipboard");
        setTimeout(() => btn.classList.remove("done"), 1500);
      } catch {
        say("Select the text and copy it");
      }
    });
  });

  // Card light and tilt under the pointer.
  $$(".tilt").forEach((card) => {
    card.addEventListener("pointermove", (e) => {
      const r = card.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width, y = (e.clientY - r.top) / r.height;
      card.style.setProperty("--px", x * 100 + "%");
      card.style.setProperty("--py", y * 100 + "%");
      if (!reduce) card.style.transform = `perspective(900px) rotateX(${(0.5 - y) * 5}deg) rotateY(${(x - 0.5) * 6}deg) translateY(-3px)`;
    });
    card.addEventListener("pointerleave", () => { card.style.transform = ""; });
  });

  // Screenshots drift at different speeds.
  const shots = $$(".shot");
  const stage = $("#stage");
  if (!reduce && stage) {
    let ticking = false;
    const move = () => {
      ticking = false;
      if (innerWidth <= 980) return;
      const r = stage.getBoundingClientRect();
      const off = r.top + r.height / 2 - innerHeight / 2;
      for (const s of shots) s.style.transform = `translate3d(0, ${-off * parseFloat(s.dataset.depth)}px, 0)`;
    };
    addEventListener("scroll", () => { if (!ticking) { ticking = true; requestAnimationFrame(move); } }, { passive: true });
    move();
  }

  // Scrambled value: random characters that settle into the masked value.
  const glyphs = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789";
  const scramble = (el) => {
    const final = el.dataset.final;
    let frame = 0;
    const total = 40;
    const step = () => {
      const keep = Math.floor((frame / total) * final.length);
      el.textContent = final.slice(0, keep) + [...final.slice(keep)].map((c) => (c === "•" || /\w/.test(c) ? glyphs[(Math.random() * glyphs.length) | 0] : c)).join("");
      if (++frame <= total) requestAnimationFrame(step);
      else el.textContent = final;
    };
    step();
  };
  if (!reduce) {
    const so = new IntersectionObserver((es) => es.forEach((e) => {
      if (e.isIntersecting) { scramble(e.target); setInterval(() => scramble(e.target), 6000); so.unobserve(e.target); }
    }), { threshold: 0.6 });
    $$(".scramble").forEach((el) => so.observe(el));
  }

  // A packet travels the path; the node it passes lights up.
  const path = $("#flow-path");
  if (path && !reduce) {
    const packet = $("#packet"), glow = $("#packet-glow");
    const nodes = $$(".flow-nodes li");
    const stops = [0.06, 0.3, 0.5, 0.7, 0.94];
    const len = path.getTotalLength();
    const svg = path.ownerSVGElement;
    let visible = false, t0 = 0;
    new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(svg);
    const loop = (now) => {
      requestAnimationFrame(loop);
      if (!visible) { t0 = now; return; }
      const t = ((now - t0) % 5200) / 5200;
      const p = path.getPointAtLength(t * len);
      packet.setAttribute("cx", p.x); packet.setAttribute("cy", p.y);
      glow.setAttribute("cx", p.x); glow.setAttribute("cy", p.y);
      const vb = svg.viewBox.baseVal.width;
      nodes.forEach((n, i) => n.classList.toggle("hit", Math.abs(p.x / vb - stops[i]) < 0.04));
    };
    requestAnimationFrame(loop);
  }

  // Terminal demo.
  const body = $("#term-body");
  const dialog = $("#dialog"), dots = $("#dialog-dots"), ok = $(".dialog-btns .ok");
  const touch = $("#touchid");
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
  const P = '<span class="p">$</span> ';
  const lines = [];
  const render = (cursor) => { body.innerHTML = lines.join("\n") + (cursor ? '<span class="cursor"></span>' : ""); };
  const out = (html) => { lines.push(html); render(true); };
  const type = async (cmd) => {
    lines.push(P);
    const i = lines.length - 1;
    for (const ch of cmd) {
      lines[i] += esc(ch);
      render(true);
      await sleep(18 + Math.random() * 38);
    }
    await sleep(320);
  };

  const finalState = () => {
    lines.length = 0;
    lines.push(P + 'secret ask GITHUB_TOKEN "Paste the token from github.com/settings/tokens"',
      '<span class="ok">stored: GITHUB_TOKEN</span>', "",
      P + "secret run --mask GITHUB_TOKEN -- gh api user -q .login", "you", "",
      P + "secret run --mask GITHUB_TOKEN -- sh -c 'echo $GITHUB_TOKEN'", '<span class="m">***</span>', "",
      P + "cat .env", '<span class="warn">Blocked by secret-cli: values stay out of the chat.</span>');
    render(false);
  };

  const run = async () => {
    for (;;) {
      lines.length = 0; render(true);
      await sleep(700);
      await type('secret ask GITHUB_TOKEN "Paste the token from github.com/settings/tokens"');
      dialog.classList.add("show");
      await sleep(700);
      dots.textContent = "";
      for (let i = 0; i < 18; i++) { dots.textContent += "•"; await sleep(40); }
      await sleep(450);
      ok.classList.add("press"); await sleep(180); ok.classList.remove("press");
      dialog.classList.remove("show");
      await sleep(250);
      out('<span class="ok">stored: GITHUB_TOKEN</span>');
      out('<span class="dim"># the agent saw the name. Never the value.</span>');
      out("");
      await sleep(900);
      await type("secret run --mask GITHUB_TOKEN -- gh api user -q .login");
      touch.classList.remove("done"); touch.classList.add("show");
      await sleep(400);
      touch.classList.add("scan");
      await sleep(1100);
      touch.classList.add("done");
      await sleep(500);
      touch.classList.remove("show", "scan");
      out("you");
      out("");
      await sleep(800);
      await type("secret run --mask GITHUB_TOKEN -- sh -c 'echo $GITHUB_TOKEN'");
      out('<span class="m">***</span>');
      out("");
      await sleep(900);
      await type("cat .env");
      out('<span class="warn">Blocked by secret-cli: values stay out of the chat.</span>');
      await sleep(5200);
    }
  };

  if (reduce) finalState();
  else run();
})();
