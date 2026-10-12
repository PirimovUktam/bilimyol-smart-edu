import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Send,
  Sparkles,
  ArrowRight,
} from 'lucide-react';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { useCourseStore } from '@/app/store/useCourseStore';

interface Message {
  id: string;
  sender: 'ai' | 'user';
  text: string;
  time: string;
  hasVisualDiagram?: boolean;
}

interface YolchiAIChatViewProps {
  onStartLesson?: () => void;
}

export const YolchiAIChatView: React.FC<YolchiAIChatViewProps> = ({ onStartLesson }) => {
  const { activeCourse } = useCourseStore();
  const [inputText, setInputText] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'm1',
      sender: 'ai',
      text: 'Salom! Men sizning shaxsiy ta’lim yo‘ldoshingiz — Yo‘lchi AI man. Savollaringizga tushunarli javob beraman, xatolaringizni pedagogik tahlil qilaman va sizga mos misollar yechib beraman. 🤖✨',
      time: '11:00',
    },
    {
      id: 'm2',
      sender: 'user',
      text: 'Kasrlarni taqqoslash va qisqartirishda adashib ketyapman. Nega 1/2 va 2/4 bir xil?',
      time: '11:01',
    },
    {
      id: 'm3',
      sender: 'ai',
      text: 'Keling, birgalikda juda sodda ko‘rib chiqaylik! Tasavvur qiling, bitta shokoladni 2 bo‘lakka bo‘lib 1 tasini oldingiz. Ikkinchi holatda esa 4 bo‘lakka bo‘lib 2 tasini oldingiz. Har ikki holatda ham aynan yarmini olgan bo‘lasiz!',
      time: '11:01',
      hasVisualDiagram: true,
    },
  ]);

  const [isTyping, setIsTyping] = useState(false);

  const quickPrompts = [
    'Qoidani sodda tushuntir 💡',
    'Yana bitta misol ber ✍️',
    'Mavzuni test qilib ko‘r 🎯',
    'Formulani ko‘rsat 📐',
  ];

  const handleSend = (textToSend?: string) => {
    const text = textToSend || inputText;
    if (!text.trim()) return;

    const userMsg: Message = {
      id: Date.now().toString(),
      sender: 'user',
      text: text.trim(),
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputText('');
    setIsTyping(true);

    setTimeout(() => {
      let aiResponseText =
        'Ajoyib savol! Matematik qoidaga ko‘ra, kasrning surat va maxrajini bir xil noldan farqli songa ko‘paytirsak yoki bo‘lsak, uning qiymati o‘zgarmaydi. Shu sababli teng kasrlar hosil bo‘ladi. Endi buni darsdagi interaktiv mashqda sinab ko‘ramizmi?';

      if (text.includes('misol')) {
        aiResponseText =
          'Mana yana bitta amaliy misol: 3/6 kasrini olaylik. 3 va 6 sonlarining har ikkalasini 3 ga bo‘lsak: 3÷3 = 1 va 6÷3 = 2. Natijada yana 1/2 hosil bo‘ladi! Demak 1/2 = 2/4 = 3/6.';
      } else if (text.includes('test')) {
        aiResponseText =
          'Siz uchun savol: 4/8 kasri 1/2 ga tengmi? Javob: Ha, chunki 4 va 8 ni 4 ga qisqartirsak 1/2 chiqadi!';
      }

      const aiMsg: Message = {
        id: (Date.now() + 1).toString(),
        sender: 'ai',
        text: aiResponseText,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };

      setMessages((prev) => [...prev, aiMsg]);
      setIsTyping(false);
    }, 900);
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6 relative">
      {/* Header bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-white/10">
        <div className="flex items-center gap-4">
          <YolchiAIMascot size="sm" mood="explaining" variant="dark" />
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl sm:text-3xl font-black text-white tracking-tight">
                Yo‘lchi AI
              </h1>
              <span className="px-2.5 py-0.5 text-[10px] font-extrabold uppercase rounded-full bg-emerald-950/80 text-emerald-300 border border-emerald-500/40 flex items-center gap-1.5 shadow-[0_0_10px_rgba(16,185,129,0.3)]">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                Online • Gemini 2.5
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              {activeCourse?.title || 'Matematika'} bo‘yicha individual yordamchi
            </p>
          </div>
        </div>

        {onStartLesson && (
          <Button
            variant="gradient"
            size="sm"
            onClick={onStartLesson}
            rightIcon={<ArrowRight className="w-4 h-4" />}
            className="font-black shadow-lg"
          >
            Interaktiv darsga o‘tish
          </Button>
        )}
      </div>

      {/* Main Chat Box Container */}
      <Card className="p-4 sm:p-6 border-white/10 shadow-2xl min-h-[500px] flex flex-col justify-between bg-slate-900/90 backdrop-blur-2xl">
        {/* Messages Stream */}
        <div className="space-y-4 overflow-y-auto max-h-[520px] pr-2">
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className={`flex flex-col ${msg.sender === 'user' ? 'items-end' : 'items-start'}`}
            >
              {/* Message Bubble */}
              <div
                className={`max-w-xl p-4 rounded-3xl text-sm leading-relaxed ${
                  msg.sender === 'user'
                    ? 'bg-gradient-to-r from-cyan-500 via-indigo-600 to-purple-600 text-white rounded-tr-xs shadow-[0_0_20px_rgba(99,102,241,0.35)] font-medium'
                    : 'bg-slate-950/85 border border-cyan-500/30 text-slate-200 rounded-tl-xs shadow-[0_0_15px_rgba(6,182,212,0.15)]'
                }`}
              >
                <div className="flex items-center justify-between gap-3 mb-1 text-[11px] font-bold opacity-80">
                  <span className={msg.sender === 'ai' ? 'text-cyan-300' : 'text-white'}>
                    {msg.sender === 'ai' ? 'Yo‘lchi AI' : 'Siz'}
                  </span>
                  <span className="text-[10px] text-slate-400">{msg.time}</span>
                </div>

                <p className="font-medium whitespace-pre-line leading-relaxed">{msg.text}</p>

                {/* Visual Mathematical Diagram inside Bubble */}
                {msg.hasVisualDiagram && (
                  <div className="mt-3 p-3.5 rounded-2xl bg-slate-900 border border-cyan-500/30 text-white shadow-inner">
                    <div className="text-xs font-black text-cyan-300 mb-2 flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
                      Vizual Taqqoslash:
                    </div>

                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4 py-2">
                      {/* Fraction 1/2 */}
                      <div className="flex items-center gap-2 bg-slate-950 px-3 py-2 rounded-xl border border-white/10 shadow-md">
                        <span className="text-base font-black text-cyan-400">1 / 2</span>
                        <div className="w-16 h-8 rounded-md border border-cyan-500/40 grid grid-cols-2 overflow-hidden">
                          <div className="bg-cyan-500" />
                          <div className="bg-slate-800" />
                        </div>
                      </div>

                      <span className="text-lg font-black text-slate-500">=</span>

                      {/* Fraction 2/4 */}
                      <div className="flex items-center gap-2 bg-slate-950 px-3 py-2 rounded-xl border border-white/10 shadow-md">
                        <span className="text-base font-black text-indigo-400">2 / 4</span>
                        <div className="w-16 h-8 rounded-md border border-indigo-500/40 grid grid-cols-4 overflow-hidden">
                          <div className="bg-indigo-500 border-r border-indigo-400" />
                          <div className="bg-indigo-500" />
                          <div className="bg-slate-800 border-r border-slate-700" />
                          <div className="bg-slate-800" />
                        </div>
                      </div>
                    </div>

                    <p className="text-[11px] font-bold text-slate-300 text-center mt-1">
                      Har ikkala to‘rtburchakning yarmi bo‘yalgan! ✅
                    </p>
                  </div>
                )}
              </div>
            </motion.div>
          ))}

          {/* Typing indicator */}
          {isTyping && (
            <div className="flex items-center gap-2 text-xs font-bold text-cyan-400 p-2">
              <span className="w-2 h-2 rounded-full bg-cyan-400 animate-bounce" />
              <span className="w-2 h-2 rounded-full bg-cyan-400 animate-bounce [animation-delay:0.2s]" />
              <span className="w-2 h-2 rounded-full bg-cyan-400 animate-bounce [animation-delay:0.4s]" />
              <span>Yo‘lchi AI o‘ylamoqda...</span>
            </div>
          )}
        </div>

        {/* Bottom Actions & Input */}
        <div className="pt-4 mt-4 border-t border-white/10 space-y-3">
          {/* Quick Prompts Chips */}
          <div className="flex flex-wrap items-center gap-2">
            {quickPrompts.map((chip, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => handleSend(chip)}
                className="px-3 py-1.5 rounded-xl border border-cyan-500/30 bg-slate-950 hover:bg-cyan-950/80 text-xs font-bold text-cyan-300 transition-all shadow-md hover:scale-102 cursor-pointer"
              >
                {chip}
              </button>
            ))}
          </div>

          {/* Text Input Pill */}
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSend();
            }}
            className="flex items-center gap-2 bg-slate-950 p-2 pl-4 rounded-2xl border border-white/10 shadow-lg focus-within:border-cyan-400 focus-within:ring-4 focus-within:ring-cyan-500/10"
          >
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              placeholder="Yo‘lchi AI ga savol bering yoki formulani so‘rang..."
              className="flex-1 text-sm bg-transparent border-0 outline-none text-white placeholder:text-slate-500 font-medium"
            />
            <Button
              type="submit"
              variant="gradient"
              size="sm"
              disabled={!inputText.trim() || isTyping}
              className="rounded-xl px-4 py-2 font-black cursor-pointer"
            >
              <Send className="w-4 h-4" />
            </Button>
          </form>
        </div>
      </Card>
    </div>
  );
};
