import RulePageClient from "./RulePageClient";

export default function RulePage({
  params,
}: {
  params: { ruleId: string };
}) {
  return <RulePageClient ruleId={params.ruleId} />;
}
