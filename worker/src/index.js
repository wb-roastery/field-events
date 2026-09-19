const REPO = "wb-roastery/field-events";
const WORKFLOW = "update-counter.yml";

export default {
  async scheduled(event, env, ctx) {
    const res = await fetch(
      `https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/dispatches`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${env.GITHUB_TOKEN}`,
          Accept: "application/vnd.github+json",
          "User-Agent": "wb-field-events-trigger",
        },
        body: JSON.stringify({ ref: "main" }),
      }
    );

    if (!res.ok) {
      console.error(`dispatch failed: ${res.status} ${await res.text()}`);
    }
  },
};
