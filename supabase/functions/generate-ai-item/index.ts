import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "npm:openai";

const openai = new OpenAI({
    apiKey: Deno.env.get("DASHSCOPE_API_KEY"),
    baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
});

const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

根据搜刮地点生成物品列表，每个物品必须包含以下字段：
- name: 独特名称（15字以内），暗示前主人或物品来历
- category: 分类，只能从以下选择：医疗、食物、工具、武器、材料、水
- rarity: 稀有度，只能从以下选择：common、uncommon、rare、epic、legendary
- story: 背景故事（50-100字），营造末日氛围

规则：
1. 物品类型要与地点紧密相关（医院出医疗物品，便利店出食物和水）
2. 名称要有创意和画面感
3. 故事要简短有画面感，可以有黑色幽默
4. 稀有度越高，名称和故事越独特精彩
5. 严格按照用户提示中的稀有度分布比例生成

只返回 JSON 数组，不要其他任何内容。`;

function getRarityWeights(dangerLevel: number): Record<string, number> {
    switch (dangerLevel) {
        case 1:
        case 2:
            return { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0 };
        case 3:
            return { common: 50, uncommon: 30, rare: 15, epic: 5, legendary: 0 };
        case 4:
            return { common: 0, uncommon: 40, rare: 35, epic: 20, legendary: 5 };
        case 5:
            return { common: 0, uncommon: 0, rare: 30, epic: 40, legendary: 30 };
        default:
            return { common: 60, uncommon: 30, rare: 10, epic: 0, legendary: 0 };
    }
}

/// 提取 AI 返回的 JSON（处理可能的 markdown 代码块包裹）
function extractJSON(text: string): string {
    const match = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (match) return match[1].trim();
    return text.trim();
}

Deno.serve(async (req: Request) => {
    // CORS preflight
    if (req.method === "OPTIONS") {
        return new Response(null, {
            status: 200,
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey"
            }
        });
    }

    try {
        const body = await req.json();
        const { poi, itemCount = 3 } = body;

        if (!poi?.name || !poi?.type) {
            return new Response(
                JSON.stringify({ success: false, error: "缺少必需的 POI 信息（name 和 type）" }),
                { status: 400, headers: { "Content-Type": "application/json" } }
            );
        }

        const dangerLevel = poi.dangerLevel || 3;
        const weights = getRarityWeights(dangerLevel);

        const userPrompt = `搜刮地点：${poi.name}（${poi.type}类型，危险等级 ${dangerLevel}/5）

请生成 ${itemCount} 个物品。严格参考以下稀有度分布比例：
${Object.entries(weights)
    .filter(([_, v]) => v > 0)
    .map(([k, v]) => `- ${k}: ${v}%`)
    .join('\n')}

返回 JSON 数组，每个元素包含 name、category、rarity、story 字段。只返回数组，不要其他内容。`;

        const completion = await openai.chat.completions.create({
            model: "qwen-flash",
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: userPrompt }
            ],
            max_tokens: 800,
            temperature: 0.8
        });

        const content = completion.choices[0]?.message?.content || "[]";
        const cleanedContent = extractJSON(content);
        const items = JSON.parse(cleanedContent);

        if (!Array.isArray(items)) {
            return new Response(
                JSON.stringify({ success: false, error: "AI 返回格式错误：非数组" }),
                { status: 500, headers: { "Content-Type": "application/json" } }
            );
        }

        console.log(`[generate-ai-item] 成功生成 ${items.length} 个物品，地点: ${poi.name}`);

        return new Response(
            JSON.stringify({ success: true, items }),
            { headers: { "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("[generate-ai-item] Error:", error);
        return new Response(
            JSON.stringify({ success: false, error: String(error) }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});
