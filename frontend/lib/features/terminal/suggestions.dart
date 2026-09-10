import 'dart:math';

const suggestedPrompts = [
  'What would he bring to an AWS migration?',
  'How does the assistant on this site work?',
  'What did he build at Savi?',
  'Which of his projects use a vector database?',
  'How does Gem run models across two different GPUs?',
  'What is the most widely used thing he has shipped?',
  'Has he run engineering for a company?',
  'What does he use for infrastructure as code?',
  'How did he get into software?',
  'What has he built with Flutter?',
  'What did he do before software?',
  'How does he keep prompt caching working with retrieval?',
  'Is he available for contract work?',
  'What is the oldest project here?',
  'How does he keep an API off the public internet?',
  'What does he know about RAG?',
  'Where is he based?',
  'Show me a project with screenshots.',
  'Can I get his resume for a backend role?',
  'Why robotics?',
  'What does he want to build next?',
  'Could he work with a team in Europe?',
  'How did a robot get him into coding?',
];

List<String> randomPrompts(int count) {
  final pool = List<String>.of(suggestedPrompts)..shuffle(Random());
  return pool.take(count).toList();
}
