'use client';

import { useEffect, useRef, useState } from 'react';
import { Pause, Play } from 'lucide-react';

export default function Galaxy() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rotation = useRef({ yaw: 0, tilt: 0.65, elapsed: 0 });
  const drag = useRef<{ pointer: number; start: number; yaw: number } | null>(
    null,
  );
  const refreshRef = useRef<() => void>(() => {});
  const [paused, setPaused] = useState(false);
  const [unavailable, setUnavailable] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext('2d', { alpha: false });
    if (!canvas || !context) {
      setUnavailable(true);
      return;
    }
    const reduced = matchMedia('(prefers-reduced-motion: reduce)');
    let visible = true;
    let frame = 0;
    let previous = 0;
    let width = 1;
    let height = 1;
    let seed = 437;
    const random = () => {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    };
    const stars = Array.from({ length: 5600 }, (_, index) => {
      const radius = Math.pow(random(), 0.72);
      const angle =
        radius * 8 +
        (index % 2) * Math.PI +
        (random() - 0.5) * (0.22 + radius * 0.7);
      return {
        x: Math.cos(angle) * radius,
        y: Math.sin(angle) * radius,
        z: (random() - 0.5) * 0.08 * (1 - radius),
        size: 0.35 + random() * 1.1,
        alpha: 0.25 + random() * 0.75,
        warm: random() < 0.26,
      };
    });
    const backdrop = Array.from({ length: 160 }, () => ({
      x: random(),
      y: random(),
      size: 0.3 + random() * 0.85,
      alpha: 0.1 + random() * 0.45,
    }));
    const draw = () => {
      context.fillStyle = '#07090e';
      context.fillRect(0, 0, width, height);
      backdrop.forEach((star) => {
        context.fillStyle = `rgba(191,210,242,${star.alpha})`;
        context.fillRect(star.x * width, star.y * height, star.size, star.size);
      });
      const compact = width < 760;
      const centerX = width * (compact ? 0.58 : 0.7);
      const centerY = height * (compact ? 0.7 : 0.49);
      const scale = Math.min(width * (compact ? 0.7 : 0.47), height * 0.55);
      const yaw = rotation.current.yaw + rotation.current.elapsed * 0.000022;
      const cosine = Math.cos(yaw);
      const sine = Math.sin(yaw);
      const tilt = rotation.current.tilt;
      const glow = context.createRadialGradient(
        centerX,
        centerY,
        0,
        centerX,
        centerY,
        scale * 0.55,
      );
      glow.addColorStop(0, '#f9e8d955');
      glow.addColorStop(0.1, '#b4cbf42b');
      glow.addColorStop(0.5, '#33599815');
      glow.addColorStop(1, '#07090e00');
      context.fillStyle = glow;
      context.fillRect(centerX - scale, centerY - scale, scale * 2, scale * 2);
      context.save();
      context.translate(centerX, centerY);
      context.rotate(-0.48);
      for (const star of stars) {
        const rotatedX = star.x * cosine - star.y * sine;
        const rotatedY = star.x * sine + star.y * cosine;
        const perspective = 1 / (1 + rotatedY * Math.sin(tilt) * 0.3);
        const screenX = rotatedX * scale * perspective;
        const screenY =
          (rotatedY * Math.cos(tilt) + star.z) * scale * perspective;
        const size = star.size * perspective;
        context.fillStyle = star.warm
          ? `rgba(242,204,162,${star.alpha})`
          : `rgba(191,216,255,${star.alpha})`;
        context.fillRect(screenX, screenY, size, size);
        if (star.size > 1.35) {
          context.fillStyle = 'rgba(152,196,255,.07)';
          context.fillRect(screenX - 2, screenY - 2, size + 4, size + 4);
        }
      }
      context.restore();
    };
    const tick = (now: number) => {
      frame = 0;
      if (document.hidden || !visible) {
        previous = 0;
        return;
      }
      if (now - previous >= 32 || !previous) {
        if (previous && !paused && !reduced.matches)
          rotation.current.elapsed += Math.min(now - previous, 80);
        previous = now;
        draw();
      }
      if (!paused && !reduced.matches) frame = requestAnimationFrame(tick);
    };
    const refresh = () => {
      if (!visible || document.hidden) return;
      if (paused || reduced.matches) draw();
      else if (!frame) frame = requestAnimationFrame(tick);
    };
    refreshRef.current = refresh;
    const resize = () => {
      const bounds = canvas.getBoundingClientRect();
      width = Math.max(1, bounds.width);
      height = Math.max(1, bounds.height);
      const ratio = Math.min(devicePixelRatio || 1, 2);
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(height * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      draw();
      refresh();
    };
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    const intersection = new IntersectionObserver((entries) => {
      visible = entries[0].isIntersecting;
      if (visible) refresh();
    });
    intersection.observe(canvas);
    document.addEventListener('visibilitychange', refresh);
    reduced.addEventListener('change', refresh);
    resize();
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
      intersection.disconnect();
      document.removeEventListener('visibilitychange', refresh);
      reduced.removeEventListener('change', refresh);
      refreshRef.current = () => {};
    };
  }, [paused]);

  return (
    <div className="galaxy">
      {unavailable && (
        <img className="galaxy-fallback" src="/images/sky.jpg" alt="" />
      )}
      <canvas
        ref={canvasRef}
        tabIndex={0}
        role="img"
        aria-label="可交互的星系艺术示意，非真实星图。左右拖动旋转，方向键调整视角；触屏竖向滑动仍可浏览页面。"
        onPointerDown={(event) => {
          if (event.isPrimary) {
            drag.current = {
              pointer: event.pointerId,
              start: event.clientX,
              yaw: rotation.current.yaw,
            };
            event.currentTarget.setPointerCapture(event.pointerId);
          }
        }}
        onPointerMove={(event) => {
          if (drag.current?.pointer === event.pointerId) {
            rotation.current.yaw =
              drag.current.yaw + (event.clientX - drag.current.start) * 0.004;
            refreshRef.current();
          }
        }}
        onPointerUp={() => {
          drag.current = null;
        }}
        onPointerCancel={() => {
          drag.current = null;
        }}
        onLostPointerCapture={() => {
          drag.current = null;
        }}
        onKeyDown={(event) => {
          if (
            ![
              'ArrowLeft',
              'ArrowRight',
              'ArrowUp',
              'ArrowDown',
              'Home',
            ].includes(event.key)
          )
            return;
          event.preventDefault();
          if (event.key === 'Home')
            rotation.current = { yaw: 0, tilt: 0.65, elapsed: 0 };
          if (event.key === 'ArrowLeft') rotation.current.yaw -= 0.15;
          if (event.key === 'ArrowRight') rotation.current.yaw += 0.15;
          if (event.key === 'ArrowUp')
            rotation.current.tilt = Math.max(0.1, rotation.current.tilt - 0.1);
          if (event.key === 'ArrowDown')
            rotation.current.tilt = Math.min(1.3, rotation.current.tilt + 0.1);
          refreshRef.current();
        }}
      />
      <noscript>
        <img
          className="galaxy-fallback"
          src="/images/sky.jpg"
          alt="星象仪夜空截图"
        />
      </noscript>
      <div className="galaxy-tools">
        <span>左右轻拖，转动星群 · 艺术示意</span>
        <button
          aria-label={paused ? '继续星群动画' : '暂停星群动画'}
          aria-pressed={paused}
          onClick={() => setPaused((value) => !value)}
        >
          {paused ? (
            <Play size={14} aria-hidden="true" />
          ) : (
            <Pause size={14} aria-hidden="true" />
          )}
        </button>
      </div>
    </div>
  );
}