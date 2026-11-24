import io, json, unittest
from server import application, MAX_REQUEST_BYTES

class NoRead(io.BytesIO):
    def read(self, *args):
        raise AssertionError('Disabled services must not read user content')

def request(path, method='GET', length='0'):
    result={}
    def start(status, headers):result.update(status=int(status.split()[0]),headers=dict(headers))
    result['body']=json.loads(b''.join(application({'PATH_INFO':path,'REQUEST_METHOD':method,
        'CONTENT_LENGTH':length,'wsgi.input':NoRead(b'private text')},start)))
    return result

class ReadinessTests(unittest.TestCase):
    def test_health_is_real_but_ai_remains_disabled(self):
        r=request('/v1/health');self.assertEqual(r['status'],200)
        self.assertEqual(r['body']['api_version'],'1')
        self.assertFalse(any(r['body']['capabilities'].values()))
    def test_closed_endpoints_do_not_read_or_echo_private_content(self):
        for path in ['/v1/translate','/v1/grammar','/v1/image-translate']:
            r=request(path,'POST','12');self.assertEqual(r['status'],503)
            self.assertEqual(r['body']['error']['code'],'feature_disabled')
            self.assertNotIn('result',r['body'])
    def test_limit_and_methods(self):
        self.assertEqual(request('/v1/translate','POST',str(MAX_REQUEST_BYTES+1))['status'],413)
        self.assertEqual(request('/v1/translate')['status'],405)
        self.assertEqual(request('/v1/health','POST')['status'],405)
        self.assertEqual(request('/v1/no-such-route')['status'],404)
    def test_invalid_size_and_no_cache(self):
        self.assertEqual(request('/v1/grammar','POST','bad')['status'],400)
        self.assertEqual(request('/v1/health')['headers']['Cache-Control'],'no-store')
if __name__=='__main__':unittest.main()
