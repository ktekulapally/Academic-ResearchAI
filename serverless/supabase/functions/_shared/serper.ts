export interface SerperHit {
  title: string;
  link: string;
  snippet: string;
}

export async function serperSearch(
  query: string,
  apiKey: string,
  num = 6
): Promise<SerperHit[]> {
  try {
    const res = await fetch("https://google.serper.dev/search", {
      method: "POST",
      headers: {
        "X-API-KEY": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ q: query, num }),
    });

    if (!res.ok) return [];

    const data = await res.json();
    const organic = (data.organic as any[]) ?? [];

    return organic.map((item) => ({
      title: String(item.title ?? ""),
      link: String(item.link ?? ""),
      snippet: String(item.snippet ?? ""),
    }));
  } catch {
    return [];
  }
}
