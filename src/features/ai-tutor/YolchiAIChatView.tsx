import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Send,
  Sparkles,
  Bot,
  Lightbulb,
  ArrowRight,
  BookOpen,
  HelpCircle,
  RefreshCw,
  CheckCircle2,
} from 'lucide-react';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { Badge } from '@/presentation/components/Badge';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLessonStore } from '@/app/store/useLessonStore';

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
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6">
      {/* Header bar matching Reference 2 */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div className="flex items-center gap-4">
          <YolchiAIMascot size="sm" mood="explaining" />
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                Yo‘lchi AI
              </h1>
              <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded-full bg-emerald-100 text-emerald-800 border border-emerald-200 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                Online
              </span>
            </div>
            <p className="text-xs text-slate-500">
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
          >
            Interaktiv darsga o‘tish
          </Button>
        )}
      </div>

      {/* Main Chat Box Container */}
      <Card className="p-4 sm:p-6 border-slate-200 shadow-md min-h-[500px] flex flex-col justify-between bg-gradient-to-b from-slate-50/50 via-white to-indigo-50/30">
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
                    ? 'bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-tr-xs shadow-md shadow-indigo-600/20'
                    : 'bg-white border border-indigo-100/80 text-slate-800 rounded-tl-xs shadow-sm'
                }`}
              >
                <div className="flex items-center justify-between gap-3 mb-1 text-[11px] font-bold opacity-80">
                  <span>{msg.sender === 'ai' ? 'Yo‘lchi AI' : 'Siz'}</span>
                  <span className="text-[10px]">{msg.time}</span>
                </div>

                <p className="font-medium whitespace-pre-line">{msg.text}</p>

                {/* Visual Mathematical Diagram inside Bubble (Reference 2 style) */}
                {msg.hasVisualDiagram && (
                  <div className="mt-3 p-3.5 rounded-2xl bg-indigo-50/70 border border-indigo-100 text-slate-900">
                    <div className="text-xs font-extrabold text-indigo-900 mb-2 flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5 text-indigo-600" />
                      Vizual Taqqoslash:
                    </div>

                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4 py-2">
                      {/* Fraction 1/2 */}
                      <div className="flex items-center gap-2 bg-white px-3 py-2 rounded-xl border border-indigo-200 shadow-2xs">
                        <span className="text-base font-black text-indigo-700">1 / 2</span>
                        <div className="w-16 h-8 rounded-md border border-indigo-300 grid grid-cols-2 overflow-hidden">
                          <div className="bg-indigo-500" />
                          <div className="bg-slate-100" />
                        </div>
                      </div>

                      <span className="text-lg font-black text-slate-400">=</span>

                      {/* Fraction 2/4 */}
                      <div className="flex items-center gap-2 bg-white px-3 py-2 rounded-xl border border-indigo-200 shadow-2xs">
                        <span className="text-base font-black text-indigo-700">2 / 4</span>
                        <div className="w-16 h-8 rounded-md border border-indigo-300 grid grid-cols-4 overflow-hidden">
                          <div className="bg-indigo-500 border-r border-indigo-400" />
                          <div className="bg-indigo-500" />
                          <div className="bg-slate-100 border-r border-slate-200" />
                          <div className="bg-slate-100" />
                        </div>
                      </div>
                    </div>

                    <p className="text-[11px] font-bold text-slate-600 text-center mt-1">
                      Har ikkala to‘rtburchakning yarmi bo‘yalgan! ✅
                    </p>
                  </div>
                )}
              </div>
            </motion.div>
          ))}

          {/* Typing indicator */}
          {isTyping && (
            <div className="flex items-center gap-2 text-xs font-bold text-indigo-600 p-2">
              <span className="w-2 h-2 rounded-full bg-indigo-500 animate-bounce" />
              <span className="w-2 h-2 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.2s]" />
              <span className="w-2 h-2 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.4s]" />
              <span>Yo‘lchi AI yozmoqda...</span>
            </div>
          )}
        </div>

        {/* Bottom Actions & Input */}
        <div className="pt-4 mt-4 border-t border-slate-100 space-y-3">
          {/* Quick Prompts Chips */}
          <div className="flex flex-wrap items-center gap-2">
            {quickPrompts.map((chip, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => handleSend(chip)}
                className="px-3 py-1.5 rounded-xl border border-indigo-200 bg-white hover:bg-indigo-50 text-xs font-bold text-indigo-700 transition-all shadow-2xs hover:scale-102 cursor-pointer"
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
            className="flex items-center gap-2 bg-white p-1.5 pl-4 rounded-2xl border border-slate-300 shadow-sm focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-200"
          >
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              placeholder="Yo‘lchi AI ga savol bering yoki formulani so‘rang..."
              className="flex-1 text-sm bg-transparent border-0 outline-none text-slate-900 placeholder:text-slate-400 font-medium"
            />
            <Button
              type="submit"
              variant="gradient"
              size="sm"
              disabled={!inputText.trim() || isTyping}
              className="rounded-xl px-4 py-2"
            >
              <Send className="w-4 h-4" />
            </Button>
          </form>
        </div>
      </Card>
    </div>
  );
};
