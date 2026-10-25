#!/usr/bin/env python3
"""Documented PC2005 v0.3.8 contract served on isolated OS-assigned loopback ports."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit, parse_qs

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def json_response(self, value, code=200):
        payload=json.dumps(value, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        self.server.requests.append({'method':'GET','path':self.path})
        if self.path=='/redirect-target':
            self.json_response({'should':'never be fetched'})
        elif self.path!='/dsh-pet-7340/state':
            self.json_response({'error':'not found'},404)
        elif self.server.mode=='redirect':
            self.send_response(302)
            self.send_header('Location','/redirect-target')
            self.send_header('Content-Length','0')
            self.end_headers()
        elif self.server.mode=='html':
            payload=b'<html>login required</html>'
            self.send_response(200)
            self.send_header('Content-Type','text/html')
            self.send_header('Content-Length',str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        else:
            self.server.state_reads+=1
            first=self.server.state_reads==1
            empty={'counter':0,'data':None}
            counter=self.server.counter
            state={
                'counter':counter+2,
                'sections':{
                    'workStatus':{'counter':counter,'data':{'state':'thinking' if first else 'success','task':None}},
                    'balance':{'counter':counter+1,'data':self.server.balance},
                    'notify':empty,'config':empty,
                },
                'pets':{'main':{
                    'say':empty,'anim':empty,'position':empty,'throw':empty,'lock':empty,
                }},
            }
            self.json_response(state)

    def do_POST(self):
        length=int(self.headers.get('Content-Length','0'))
        body=json.loads(self.rfile.read(length) or b'{}')
        self.server.requests.append({'method':'POST','path':self.path,'body':body})
        parsed=urlsplit(self.path)
        query=parse_qs(parsed.query)
        if parsed.path in ['/dsh-pet-7340/whisper','/dsh-pet-7340/chat'] and query!={'pet':['main'],'surface':['any']}:
            self.json_response({'ok':False,'reason':'bad-request'})
            return
        time.sleep(.12)
        if parsed.path=='/dsh-pet-7340/whisper' and body=={}:
            self.json_response({'ok':True,'text':'fixture-whisper'})
        elif parsed.path=='/dsh-pet-7340/chat' and body=={'text':'hello fixture'}:
            self.json_response({'ok':True,'text':'fixture-chat'})
        elif parsed.path=='/dsh-pet-7340/chat' and body=={'text':'fixture-error'}:
            self.json_response({'ok':False,'reason':'provider-missing'})
        elif parsed.path=='/dsh-pet-7340/balance' and body=={}:
            self.server.balance={'ok':False,'provider':'fixture','reason':'unsupported'}
            self.json_response({'ok':True})
        else:
            self.json_response({'error':'unexpected action'},400)

def make_server(mode):
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    server.requests=[]
    server.mode=mode
    server.counter=int(time.time()*1000)
    server.state_reads=0
    server.balance=None
    thread=threading.Thread(target=server.serve_forever,daemon=True)
    thread.start()
    return server,thread

def main():
    if len(sys.argv)!=3:
        raise SystemExit('Usage: backend_http_fixture.py <native-harness> <output-directory>')
    harness=Path(sys.argv[1]).resolve()
    output=Path(sys.argv[2]).resolve()
    output.mkdir(parents=True,exist_ok=True)
    servers=[make_server(mode) for mode in ['regular','redirect','html','regular']]
    try:
        proc=subprocess.run([str(harness)]+[f'http://127.0.0.1:{s.server_port}' for s,_ in servers]+[str(output/'backend-native-http-report.json')],capture_output=True,text=True,timeout=40)
        (output/'backend-native-http-stdout.txt').write_text(proc.stdout)
        (output/'backend-native-http-stderr.txt').write_text(proc.stderr)
        regular=servers[0][0].requests
        requests=[r for s,_ in servers for r in s.requests]
        allowed=['/dsh-pet-7340/state','/dsh-pet-7340/whisper','/dsh-pet-7340/chat','/dsh-pet-7340/balance']
        report={
            'nativeHarnessExitCode':proc.returncode,
            'regularRequests':regular,
            'documentedStateRead':any(r['method']=='GET' and r['path']=='/dsh-pet-7340/state' for r in regular),
            'exactlyOneWhisper':sum(r['method']=='POST' and r['path']=='/dsh-pet-7340/whisper?pet=main&surface=any' for r in regular)==1,
            'exactlyTwoChats':sum(r['method']=='POST' and r['path']=='/dsh-pet-7340/chat?pet=main&surface=any' for r in regular)==2,
            'exactlyOneBalance':sum(r['method']=='POST' and r['path']=='/dsh-pet-7340/balance' for r in regular)==1,
            'noUndocumentedInteractions':all(urlsplit(r['path']).path in allowed for r in regular),
            'redirectTargetNotFetched':not any(r['path']=='/redirect-target' for r in requests),
            'fixtureServersUseOSAssignedLoopbackPorts':True,
        }
        report['passed']=proc.returncode==0 and all(v for k,v in report.items() if isinstance(v,bool))
        (output/'backend-http-fixture-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
        print(proc.stdout)
        if proc.stderr:print(proc.stderr,file=sys.stderr)
        print(json.dumps(report,ensure_ascii=False,indent=2))
        return 0 if report['passed'] else 1
    finally:
        for server,thread in servers:
            server.shutdown();server.server_close();thread.join(timeout=2)

if __name__=='__main__':
    raise SystemExit(main())
