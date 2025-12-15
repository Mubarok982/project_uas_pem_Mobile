import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 1. Handle CORS (Agar Flutter bisa akses)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 2. Cek API Key
    const apiKey = Deno.env.get('GOOGLE_API_KEY')
    if (!apiKey) throw new Error('API Key belum di-set di Server Supabase!')

    // 3. Ambil Data dari Flutter
    const { productName, imageBase64 } = await req.json()
    if (!productName || !imageBase64) throw new Error("Data nama/gambar kosong")

    // --- SETUP PROMPT AGAR AI LEBIH PINTAR ---
    const promptText = `
      Peran: Kamu adalah sistem verifikasi otomatis e-commerce.
      Data Transaksi: User membeli produk bernama '${productName}'.
      Tugas: Lihat gambar ini. Apakah gambar ini menampilkan produk '${productName}'?
      
      Aturan Penilaian:
      1. Jawab 'valid' jika produk terlihat jelas, mirip, atau ada dalam kemasan/kotak yang sesuai.
      2. Jawab 'invalid' jika gambar menampilkan benda yang SAMA SEKALI BERBEDA (misal: beli HP foto batu, atau foto lantai kosong).
      3. Jawab 'invalid' jika gambar gelap gulita atau blur parah hingga tidak terlihat apapun.

      Format Jawaban Wajib (Gunakan tanda pipe '|'):
      STATUS|ALASAN SINGKAT
      
      Contoh:
      valid|Gambar sesuai dengan deskripsi produk.
      invalid|Gambar menampilkan sandal jepit, padahal produk adalah laptop.
    `;

    // 4. URL Model (Pakai gemini-flash-latest sesuai yang jalan di akunmu)
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`

    const requestBody = {
      contents: [{
        parts: [
          { text: promptText }, // Gunakan prompt pintar di atas
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: imageBase64
            }
          }
        ]
      }]
    }

    console.log(`Mengirim request verifikasi untuk: ${productName}...`)

    // 5. Kirim Request ke Google
    const googleResponse = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    })

    const data = await googleResponse.json()

    // 6. Cek Error dari Google
    if (!googleResponse.ok) {
      console.error("Google AI Error Details:", JSON.stringify(data))
      throw new Error(data.error?.message || "Google menolak request ini.")
    }

    // 7. Ambil Jawaban Teks
    const textResult = data.candidates?.[0]?.content?.parts?.[0]?.text
    if (!textResult) throw new Error("AI diam saja (tidak ada jawaban text).")

    // 8. Kembalikan ke Flutter
    return new Response(JSON.stringify({ result: textResult }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error("Function Error:", error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})