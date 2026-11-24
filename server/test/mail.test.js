import test from 'node:test';
import assert from 'node:assert/strict';
import {mailer} from '../src/mail.js';
import {config} from '../src/config.js';

test('Gmail transport preserves TLS validation on 465 and STARTTLS 587', async()=>{
  for(const port of [465,587]) {
    let settings, letter;
    const mail=mailer({gmail:'sender@example.com',gmailPassword:'test-password',smtpPort:port},{
      createTransport:opts=>{settings=opts;return {sendMail:async data=>{letter=data;return {accepted:['recipient@example.com']};}};},
    });
    await mail.send('recipient@example.com','012345','register');
    assert.equal(settings.host,'smtp.gmail.com');assert.equal(settings.port,port);
    assert.equal(settings.secure,port===465);assert.equal(settings.requireTLS,true);
    assert.equal(settings.tls.rejectUnauthorized,true);
    assert.match(letter.text,/012345/);assert.match(letter.text,/10 daqiqa/);
    assert.ok(!letter.html.includes('test-password'));
  }
});
test('A resolved SMTP response without accepted recipient is a delivery failure',async()=>{
 const mail=mailer({}, {createTransport:()=>({sendMail:async()=>({accepted:[],rejected:['recipient@example.com']})})});
 await assert.rejects(mail.send('recipient@example.com','012345','reset'),e=>e.code==='EENVELOPE');
});
test('SMTP port input rejects arbitrary outbound endpoints',()=>{
 assert.throws(()=>config({JWT_SECRET:'x'.repeat(40),GMAIL_SMTP_PORT:'25'}));
 assert.equal(config({JWT_SECRET:'x'.repeat(40),GMAIL_SMTP_PORT:'587'}).smtpPort,587);
});
