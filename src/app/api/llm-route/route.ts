import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Add middleware config to skip auth
export const config = {
  api: {
    auth: false,
  },
};

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions";

type RequestBody = {
  transaction_date: string;
  transaction_description: string;
  transaction_amount: string;
  category: {
    name: string;
    description?: string;
  };
  ai_prompt?: string;
};

type ResponseBody = {
  decision: "apply" | "do not apply";
  explanation?: string;
};

type OpenRouterResponse = {
  choices: Array<{
    message: {
      content: string;
      role: string;
      function_call?: {
        arguments: string;
      };
    };
    index: number;
  }>;
};

export async function POST(request: NextRequest) {
  try {
    if (!OPENROUTER_API_KEY) {
      throw new Error("OpenRouter API key not configured");
    }

    const body = (await request.json()) as RequestBody;

    if (!body.ai_prompt) {
      return NextResponse.json({ 
        decision: "do not apply",
        explanation: "No AI prompt provided" 
      });
    }

    const response = await fetch(OPENROUTER_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000",
        "X-Title": "Soraban Project",
      },
      body: JSON.stringify({
        model: "openai/gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `You are a financial transaction categorization assistant. Your task is to decide if a transaction should be categorized based on the given information.
You must respond in a structured JSON format with only a "decision" field that must be either "apply" or "do not apply".`
          },
          {
            role: "user",
            content: `Analyze this transaction:
- Description: ${body.transaction_description}
- Amount: ${body.transaction_amount}
- Date: ${body.transaction_date}

For this category:
- Name: ${body.category.name}
${body.category.description ? `- Description: ${body.category.description}` : ''}

Using this rule:
${body.ai_prompt}

Respond only with a JSON object containing a "decision" field with value "apply" or "do not apply".
Example: {"decision": "apply"} or {"decision": "do not apply"}`
          }
        ],
        temperature: 0.1,
        max_tokens: 50,
        stream: false,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "decision",
            strict: true,
            schema: {
              required: ["decision","explanation"],
              type: "object",
              properties: {
                decision: {
                  type: "string",
                  enum: ["apply", "do not apply"],
                  description: "Whether to apply the rule or not"
                },
                explanation: {
                  type: "string",
                  description: "Explanation for the decision"
                }
              },
              additionalProperties: false
            }
          }
        }
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('OpenRouter API error:', errorText);
      throw new Error(`OpenRouter API error: ${response.status} ${response.statusText} - ${errorText}`);
    }

    const completion = await response.json() as OpenRouterResponse;
    const responseContent = completion.choices[0]?.message.content;
    
    if (!responseContent) {
      throw new Error("No response from AI");
    }

    try {
      const parsedResponse = JSON.parse(responseContent) as { decision: "apply" | "do not apply" };
      return NextResponse.json({
        decision: parsedResponse.decision
      });
    } catch (error) {
      console.error("Failed to parse AI response:", error);
      throw new Error("Invalid response format from AI");
    }

  } catch (error) {
    console.error("Error in LLM route:", error instanceof Error ? error.message : "Unknown error");
    return NextResponse.json(
      { 
        decision: "do not apply",
        explanation: "Error processing request" 
      },
      { status: 500 }
    );
  }
} 