'use client';
import { useEffect, useState } from 'react';
export default function Page() {
  const [buildId] = useState('demo-build');
  const [text, setText] = useState('');
  const [messages, setMessages] = useState<string[]>([]);
  useEffect(() => {
    const es = new EventSource(`/api/builds/${buildId}/stream`);
    es.onmessage = (ev) => setMessages((m) => [...m, (JSON.parse(ev.data) as { text: string }).text]);
    return () => es.close();
  }, [buildId]);
  return <main><h1>Vibe Platform v0+M2</h1><input value={text} onChange={(e)=>setText(e.target.value)} /><button onClick={async ()=>{await fetch(`/api/builds/${buildId}/messages`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({text})});setText('');}}>Send</button><ul>{messages.map((m,i)=><li key={i}><pre>{m}</pre></li>)}</ul><iframe title="preview" /></main>;
}
