export function cameraError(error) {
  if (["NotAllowedError", "SecurityError"].includes(error?.name))
    return "Kameraga ruxsat berilmadi. Brauzer sozlamalaridan ruxsatni yoqing yoki galereyadan rasm tanlang.";
  if (["NotFoundError", "OverconstrainedError"].includes(error?.name))
    return "Kamera topilmadi. Galereyadan rasm tanlashingiz mumkin.";
  if (error?.name === "NotReadableError")
    return "Kamera boshqa ilovada band. Uni yoping va qayta urinib ko‘ring.";
  return "Kamera ochilmadi. HTTPS orqali kiring yoki galereyadan rasm tanlang.";
}

// Own the stream and invalidate pending permission prompts when the view closes.
export class CameraSession {
  constructor(mediaDevices) {
    this.devices = mediaDevices;
    this.generation = 0;
    this.stream = null;
    this.video = null;
  }
  async open(video) {
    this.stop();
    const generation = this.generation;
    const stream = await this.devices.getUserMedia({
      audio: false,
      video: { facingMode: { ideal: "environment" }, width: { ideal: 1600 }, height: { ideal: 1200 } },
    });
    if (generation !== this.generation) {
      stream.getTracks().forEach((track) => track.stop());
      return false;
    }
    this.stream = stream;
    this.video = video;
    video.srcObject = stream;
    try {
      await video.play();
      return generation === this.generation;
    } catch (error) {
      if (generation === this.generation) this.stop();
      throw error;
    }
  }
  async capture() {
    const video = this.video, generation = this.generation;
    if (!this.stream || !video?.videoWidth || !video?.videoHeight)
      throw Error("Kamera tayyor bo‘lishini kuting.");
    const scale = Math.min(1, 1600 / Math.max(video.videoWidth, video.videoHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
    canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
    canvas.getContext("2d").drawImage(video, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", .88));
    if (generation !== this.generation) return null;
    if (!blob) throw Error("Surat olinmadi. Qayta urinib ko‘ring.");
    return new File([blob], "lingoy-surati.jpg", { type: "image/jpeg" });
  }
  stop() {
    this.generation++;
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;
    if (this.video) this.video.srcObject = null;
    this.video = null;
  }
}
