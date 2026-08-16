import React, { useState } from 'react';
import { motion } from 'framer-motion';

export const MathFunctionGraph: React.FC = () => {
  const [sliderX, setSliderX] = useState<number>(4);

  // f(x) = 2x + 3
  const calcY = (x: number) => 2 * x + 3;
  const currentY = calcY(sliderX);

  const points = [
    { x: 0, y: 3 },
    { x: 1, y: 5 },
    { x: 2, y: 7 },
    { x: 4, y: 11 },
  ];

  // SVG coordinate transformation
  // x: 0..5 -> svgX: 50..350
  // y: 0..15 -> svgY: 260..40
  const toSvgX = (x: number) => 50 + (x / 5) * 300;
  const toSvgY = (y: number) => 260 - (y / 15) * 220;

  return (
    <div className="bg-slate-900 text-white rounded-2xl p-6 border border-slate-800 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <span className="text-xs font-bold text-blue-400 uppercase tracking-wider">
            Interaktiv Grafik Modeli
          </span>
          <h4 className="text-lg font-bold text-white font-mono">f(x) = 2x + 3</h4>
        </div>
        <div className="text-right">
          <span className="text-xs text-slate-400 block">Joriy qiymat:</span>
          <span className="text-sm font-bold text-teal-400 font-mono">
            f({sliderX}) = 2 × {sliderX} + 3 = <strong className="text-white text-base">{currentY}</strong>
          </span>
        </div>
      </div>

      {/* SVG Canvas */}
      <div className="w-full h-56 bg-slate-950/80 rounded-xl border border-slate-800 relative overflow-hidden flex items-center justify-center p-2">
        <svg viewBox="0 0 400 300" className="w-full h-full">
          {/* Grid lines */}
          {[0, 1, 2, 3, 4, 5].map((gx) => (
            <line
              key={`gx-${gx}`}
              x1={toSvgX(gx)}
              y1={40}
              x2={toSvgX(gx)}
              y2={260}
              stroke="rgba(255,255,255,0.07)"
              strokeDasharray="2 2"
            />
          ))}
          {[0, 3, 5, 7, 9, 11, 13, 15].map((gy) => (
            <line
              key={`gy-${gy}`}
              x1={50}
              y1={toSvgY(gy)}
              x2={350}
              y2={toSvgY(gy)}
              stroke="rgba(255,255,255,0.07)"
              strokeDasharray="2 2"
            />
          ))}

          {/* Coordinate Axes */}
          <line x1="50" y1="260" x2="360" y2="260" stroke="#64748b" strokeWidth="2" />
          <line x1="50" y1="270" x2="50" y2="30" stroke="#64748b" strokeWidth="2" />
          <text x="365" y="265" fill="#94a3b8" fontSize="11" fontWeight="bold">X</text>
          <text x="45" y="25" fill="#94a3b8" fontSize="11" fontWeight="bold">Y</text>

          {/* Axis Labels */}
          {[0, 1, 2, 3, 4, 5].map((lx) => (
            <text key={`lx-${lx}`} x={toSvgX(lx)} y="278" fill="#94a3b8" fontSize="10" textAnchor="middle">
              {lx}
            </text>
          ))}
          {[0, 3, 5, 7, 11, 15].map((ly) => (
            <text key={`ly-${ly}`} x="38" y={toSvgY(ly) + 3} fill="#94a3b8" fontSize="10" textAnchor="end">
              {ly}
            </text>
          ))}

          {/* Linear Function Line (0,3) to (5,13) */}
          <line
            x1={toSvgX(0)}
            y1={toSvgY(3)}
            x2={toSvgX(5)}
            y2={toSvgY(13)}
            stroke="#3b82f6"
            strokeWidth="3"
            strokeLinecap="round"
          />

          {/* Predefined Static Points */}
          {points.map((pt, i) => (
            <g key={i}>
              <circle
                cx={toSvgX(pt.x)}
                cy={toSvgY(pt.y)}
                r="5"
                fill="#14b8a6"
                stroke="white"
                strokeWidth="2"
              />
              <text
                x={toSvgX(pt.x) + 8}
                y={toSvgY(pt.y) - 6}
                fill="#cbd5e1"
                fontSize="10"
                fontFamily="monospace"
              >
                ({pt.x}, {pt.y})
              </text>
            </g>
          ))}

          {/* Active User Slider Point */}
          <motion.circle
            cx={toSvgX(sliderX)}
            cy={toSvgY(currentY)}
            r="8"
            fill="#f59e0b"
            stroke="#ffffff"
            strokeWidth="3"
            className="drop-shadow-lg"
          />
        </svg>
      </div>

      {/* Interactive Slider */}
      <div className="space-y-1">
        <div className="flex justify-between text-xs text-slate-400">
          <span>x qiymatini o‘zgartiring:</span>
          <span className="font-mono font-bold text-white">x = {sliderX}</span>
        </div>
        <input
          type="range"
          min="0"
          max="5"
          step="1"
          value={sliderX}
          onChange={(e) => setSliderX(Number(e.target.value))}
          className="w-full accent-blue-500 cursor-pointer h-2 bg-slate-800 rounded-lg"
        />
      </div>
    </div>
  );
};
