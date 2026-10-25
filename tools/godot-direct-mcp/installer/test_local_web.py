# Windows integration tests: localhost browser UI, CSRF/Host validation, copy links.
import importlib.util
import json
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest import mock
from urllib.request import Request, urlopen
from urllib.error import HTTPError

import local_web as page


class WebPanelTests(unittest.TestCase):
    def setUp(self):
        self.tmp=TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.old=(page.PANEL_PORT,page.legacy.INSTALL_DIR,page.legacy.CONFIG_FILE,
                  page.legacy.RUNTIME_FILE,page.legacy.DIAGNOSTIC_FILE,page.state)
        page.legacy.INSTALL_DIR=self.root
        page.legacy.CONFIG_FILE=self.root/"settings.json"
        page.legacy.RUNTIME_FILE=self.root/"runtime.json"
        page.legacy.DIAGNOSTIC_FILE=self.root/"diagnostic.log"
        page.state=page.State()
        self.http=ThreadingHTTPServer(("127.0.0.1",0),page.LocalHandler)
        page.PANEL_PORT=self.http.server_port
        self.base=f"http://127.0.0.1:{page.PANEL_PORT}"
        self.thread=threading.Thread(target=self.http.serve_forever,daemon=True)
        self.thread.start()

    def tearDown(self):
        self.http.shutdown()
        self.http.server_close()
        self.thread.join(2)
        (page.PANEL_PORT,page.legacy.INSTALL_DIR,page.legacy.CONFIG_FILE,
         page.legacy.RUNTIME_FILE,page.legacy.DIAGNOSTIC_FILE,page.state)=self.old

    def req(self,path,post=False,header=None):
        headers={"Host":f"127.0.0.1:{page.PANEL_PORT}"}
        if post:headers.update({"Content-Type":"application/json","X-CHK-UI":page.state.csrf})
        if header:headers.update(header)
        r=Request(self.base+path,method="POST" if post else "GET",headers=headers,
                  data=b"{}" if post else None)
        try:
            with urlopen(r,timeout=3) as v:return v.status,v.read().decode("utf-8")
        except HTTPError as ex:return ex.code,ex.read().decode("utf-8")

    def test_page_is_local_and_shows_installation_controls(self):
        code,html=self.req("/")
        self.assertEqual(code,200)
        self.assertIn("INSTALLER ET CONNECTER AUTOMATIQUEMENT",html)
        self.assertIn("COPIER MON LIEN CHATGPT",html)
        self.assertIn(page.state.csrf,html)
        self.assertIn("http://127.0.0.1:8792",page.PANEL_URL)
        self.assertNotIn("Render",html)
        self.assertNotIn("Supabase",html)

    def test_health_route(self):
        status,body=self.req("/api/health")
        self.assertEqual(status,200)
        self.assertEqual(json.loads(body)["version"],"1.2.1")

    def test_no_cross_origin_post(self):
        for headers in ({"X-CHK-UI":"wrong"},
                        {"Origin":"https://attacker.example"}):
            status,_=self.req("/api/install",True,headers)
            self.assertEqual(status,403)

    def test_local_connection_status_has_no_private_tokens(self):
        page.legacy.create_config_once()
        status,body=self.req("/api/status")
        self.assertEqual(status,200)
        data=json.loads(body)
        self.assertEqual(data["configured"],True)
        self.assertNotIn("chat_token",data)
        self.assertNotIn("editor_token",data)

    def test_private_url_not_returned_until_public_protocol_verified(self):
        cfg=page.legacy.create_config_once()
        status,body=self.req("/api/copy-chat",True)
        self.assertEqual(status,409)
        page.state.finish(hostname="safe.ts.net")
        status,body=self.req("/api/copy-chat",True)
        self.assertEqual(status,200)
        self.assertEqual(json.loads(body)["value"],f"https://safe.ts.net:10000/mcp/{cfg['chat_token']}")

    def test_private_url_refused_via_rebound_host(self):
        status,_=self.req("/",header={"Host":"malicious.test"})
        self.assertEqual(status,403)

    def test_diagnostic_redacts_key(self):
        token="f"*64
        page.legacy.DIAGNOSTIC_FILE.write_text("test error "+token,encoding="utf-8")
        status,body=self.req("/api/diagnostic",True)
        self.assertEqual(status,200)
        self.assertNotIn(token,body)
        self.assertIn("[CLÉ MASQUÉE]",body)

    def test_start_one_install_worker_only(self):
        with mock.patch.object(page,"install_and_connect") as worker:
            code,_=self.req("/api/install",True)
            self.assertEqual(code,202)
            self.assertTrue(page.state.snapshot()["busy"])


if __name__=="__main__":
    unittest.main()
