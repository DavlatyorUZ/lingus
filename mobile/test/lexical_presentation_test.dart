import 'package:flutter_test/flutter_test.dart';
import 'package:lingoy/core/lexical_presentation.dart';

void main(){
 test('Synonyms are scoped to one meaning and reject mismatched membership',(){
  expect(senseSynonyms('bank',{'words':['bank','depository','Depository','financial institution']}),['depository','financial institution']);
  expect(senseSynonyms('run',{'words':['walk','stroll']}),isEmpty);
  expect(senseSynonyms('big',{'words':['big',...List.generate(1000,(i)=>'word$i')]}).length,6);
 });
 test('Examples are at most three across both sources, with existing grammar variety',(){
  final result=senseExamples({'bilingual_examples':[{'en':'I start now.','uz':'Hozir boshlayman.'}],'examples':['I start now.','We start early.','I do not start late.','Do you start today?','They start again.']});
  expect(result.map((e)=>e.en),['I start now.','I do not start late.','Do you start today?']);expect(result.first.uz,'Hozir boshlayman.');
  expect(senseExamples({'examples':'broken json'}),isEmpty);
 });
}
