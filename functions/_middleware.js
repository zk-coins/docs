// Legacy host redirect: docs.zkcoins.app → docs.zkcoins.com (301 permanent).

export async function onRequest(context) {
  const url = new URL(context.request.url);
  const host = url.hostname;

  if (host === "docs.zkcoins.app") {
    return new Response(null, {
      status: 301,
      headers: {
        Location: "https://docs.zkcoins.com" + url.pathname + url.search,
      },
    });
  }

  return context.next();
}
