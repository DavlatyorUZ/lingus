// User-initiated speech only. No audio is stored by Lingoy.
export function voiceSearch(reverse = false, environment = globalThis) {
  const Recognition = environment.SpeechRecognition || environment.webkitSpeechRecognition;
  if (!Recognition) throw Error('Bu brauzer ovozli qidiruvni qo‘llamaydi. Matn bilan qidiring.');
  const recognition = new Recognition();
  recognition.lang = reverse ? 'uz-UZ' : 'en-US';
  recognition.continuous = false;
  recognition.interimResults = false;
  recognition.maxAlternatives = 1;
  let done = false, resolve, reject;
  const result = new Promise((yes, no) => { resolve = yes; reject = no; });
  const finish = (value, error) => {
    if (done) return;
    done = true;
    clearTimeout(timeout);
    error ? reject(error) : resolve(value);
  };
  recognition.onresult = event => {
    const text = event.results?.[0]?.[0]?.transcript?.trim();
    finish(text?.length > 160 ? null : text || null, text?.length > 160 ? Error('Qisqaroq so‘z yoki ibora ayting.') : null);
  };
  recognition.onerror = event => {
    if (event.error === 'aborted' || event.error === 'no-speech') finish(null);
    else finish(null, Error(event.error === 'not-allowed' || event.error === 'service-not-allowed'
      ? 'Brauzerda mikrofon ruxsatini yoqing yoki matn bilan qidiring.'
      : 'Ovoz aniqlanmadi. Internet va nutqni tanish xizmatini tekshiring.'));
  };
  recognition.onend = () => finish(null);
  const timeout = setTimeout(() => { finish(null); recognition.abort(); }, 20000);
  try { recognition.start(); } catch { finish(null, Error('Mikrofon ochilmadi. Qayta urinib ko‘ring.')); }
  return { result, cancel: () => { finish(null); recognition.abort(); } };
}
