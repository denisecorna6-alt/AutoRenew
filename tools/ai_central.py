#!/usr/bin/env python3
import concurrent.futures, json, os, sys, urllib.request, urllib.error
from pathlib import Path
from datetime import datetime, timezone

def call(url, headers, payload, secret):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={**headers, "Content-Type":"application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=90) as r: return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        body=e.read(3000).decode("utf-8","replace").replace(secret,"[REDACTED]")
        raise RuntimeError(f"HTTP {e.code}: {body[:1000]}") from None

def need(name):
    value=os.getenv(name,"").strip()
    if not value: raise RuntimeError("Secret ausente: "+name)
    return value

def main():
    task=os.getenv("AI_TASK","").strip()[:6000]
    context=os.getenv("AI_CONTEXT","").strip()[:18000]
    if not task: raise RuntimeError("Informe a tarefa.")
    keys={"OpenAI":need("OPENAI_API_KEY"),"Claude":need("ANTHROPIC_API_KEY"),"Gemini":need("GEMINI_API_KEY")}
    models={"OpenAI":os.getenv("OPENAI_MODEL","gpt-6.1-sol"),"Claude":os.getenv("ANTHROPIC_MODEL","claude-sonnet-5-5"),"Gemini":os.getenv("GEMINI_MODEL","gemini-3.8-flash")}
    system="Você é revisor independente do AutoRenew. Priorize segurança, privacidade, estabilidade iOS e testes. Não invente evidências, não recomende senha Apple ID ou endpoints privados Apple. Não altere código nem aprove publicação. Responda em português do Brasil."
    prompt=f"TAREFA:\n{task}\n\nCONTEXTO:\n{context or '(não fornecido)'}\n\nListe entendimento, riscos, recomendações priorizadas, testes verificáveis e decisões humanas. Separe fatos, hipóteses e dúvidas."
    def oa():
        d=call("https://api.openai.com/v1/responses",{"Authorization":"Bearer "+keys["OpenAI"]},{"model":models["OpenAI"],"instructions":system,"input":prompt,"max_output_tokens":1600},keys["OpenAI"])
        if d.get("output_text"): return d["output_text"]
        return "\\n".join(x.get("text","") for o in d.get("output",[]) for x in o.get("content",[]) if x.get("type")=="output_text")
    def cl():
        d=call("https://api.anthropic.com/v1/messages",{"x-api-key":keys["Claude"],"anthropic-version":"2023-06-01"},{"model":models["Claude"],"max_tokens":1600,"system":system,"messages":[{"role":"user","content":prompt}]},keys["Claude"])
        return "\n".join(x.get("text","") for x in d.get("content",[]) if x.get("type")=="text")
    def ge():
        url="https://generativelanguage.googleapis.com/v1beta/models/"+models["Gemini"]+":generateContent"
        d=call(url,{"x-goog-api-key":keys["Gemini"]},{"systemInstruction":{"parts":[{"text":system}]},"contents":[{"role":"user","parts":[{"text":prompt}]}],"generationConfig":{"maxOutputTokens":1600}},keys["Gemini"])
        return "\n".join(x.get("text","") for x in d["candidates"][0]["content"]["parts"] if "text" in x)
    funcs={"OpenAI":oa,"Claude":cl,"Gemini":ge}
    reviews,errors={},{}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs={pool.submit(fn):name for name,fn in funcs.items()}
        for job in concurrent.futures.as_completed(jobs):
            name=jobs[job]
            try: reviews[name]=job.result()
            except Exception as e: errors[name]=str(e)[:1200]
    if not reviews: raise RuntimeError("Nenhuma IA respondeu. Confira segredos, modelos e faturamento.")
    synthesis="Síntese indisponível; veja as revisões individuais."
    if "OpenAI" in reviews:
        combined="Tarefa: "+task+"\n\n"+"\n\n".join("REVISÃO "+n+":\n"+v for n,v in reviews.items())
        combined+="\n\nSintetize consensos, divergências, riscos, plano e testes. Não invente fatos nem aprove mudanças."
        try:
            d=call("https://api.openai.com/v1/responses",{"Authorization":"Bearer "+keys["OpenAI"]},{"model":models["OpenAI"],"instructions":"Você coordena revisões técnicas. Compare criticamente, destaque divergências e decisões humanas. PT-BR.","input":combined[:30000],"max_output_tokens":1600},keys["OpenAI"])
            synthesis=d.get("output_text") or "\\n".join(x.get("text","") for o in d.get("output",[]) for x in o.get("content",[]) if x.get("type")=="output_text")
        except Exception as e: errors["Síntese OpenAI"]=str(e)[:1200]
    lines=["# Central de IAs — AutoRenew","", "Data UTC: "+datetime.now(timezone.utc).isoformat(),"Tarefa: "+task,"Modo: revisão somente; nenhuma alteração de código/publicação executada.","","## Síntese",synthesis,""]
    for n in ("OpenAI","Claude","Gemini"):
        if n in reviews: lines += ["## Revisão "+n+" ("+models[n]+")",reviews[n],""]
    if errors: lines += ["## Falhas"]+["- "+n+": "+v for n,v in errors.items()]
    lines += ["","## Governança","Use recomendações como sugestões. Faça alterações em Alpha e valide testes; nunca faça merge ou release automaticamente."]
    Path("ai-central-report.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    summary=os.getenv("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary,"a",encoding="utf-8") as f: f.write("# Central de IAs concluída\nRelatório completo no artefato ai-central-report.\n")
    print("Relatório gerado. Provedores respondidos: "+", ".join(reviews))
    if errors: print("Provedores com falha: "+", ".join(errors))
if __name__=="__main__":
    try: main()
    except Exception as e:
        print("ERRO: "+str(e),file=sys.stderr)
        sys.exit(1)
