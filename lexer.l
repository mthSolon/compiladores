%{
#include <stdio.h>
#include <string.h>
#include "parser.tab.h"

void yyerror(const char *s);
%}

%%
[ \t\n]+                           { /* ignore whitespace */ }
"//".*                             { /* ignore comments */ }

"config"                           { return CONFIG; }
"fim"                              { return FIM; }
"repita"                           { return REPITA; }
"var"                              { return VAR; }
"inteiro"                          { return INTEIRO; }
"booleano"                         { return BOOLEANO; }
"texto"                            { return TEXTO; }
"configurar"                       { return CONFIGURAR; }
"como"                             { return COMO; }
"saida"                            { return SAIDA; }
"entrada"                          { return ENTRADA; }
"configurarPWM"                    { return CONFIGURAR_PWM; }
"com"                              { return COM; }
"frequencia"                       { return FREQUENCIA; }
"resolucao"                        { return RESOLUCAO; }
"ajustarPWM"                       { return AJUSTAR_PWM; }
"valor"                            { return VALOR; }
"ligar"                            { return LIGAR; }
"desligar"                         { return DESLIGAR; }
"lerDigital"                       { return LER_DIGITAL; }
"lerAnalogico"                     { return LER_ANALOGICO; }
"conectarWifi"                     { return CONECTAR_WIFI; }
"enviarHttp"                       { return ENVIAR_HTTP; }
"configurarSerial"                 { return CONFIGURAR_SERIAL; }
"escreverSerial"                   { return ESCREVER_SERIAL; }
"lerSerial"                        { return LER_SERIAL; }
"se"                               { return SE; }
"entao"                            { return ENTAO; }
"senao"                            { return SENAO; }
"enquanto"                         { return ENQUANTO; }
"esperar"                          { return ESPERAR; }

"=="                               { return IGUAL; }
"!="                               { return DIFERENTE; }
"<"                                { return MENOR; }
">"                                { return MAIOR; }
"<="                               { return MENOR_IGUAL; }
">="                               { return MAIOR_IGUAL; }
"="                                { return ATRIBUICAO; }
"+"                                { return MAIS; }
"-"                                { return MENOS; }
"*"                                { return VEZES; }
"/"                                { return DIVIDIDO; }
";"                                { return PONTO_VIRGULA; }
":"                                { return DOIS_PONTOS; }
","                                { return VIRGULA; }

[0-9]+                             { yylval.num = atoi(yytext); return NUMERO; }
\"[^\"]*\"                         { 
                                     yylval.str = strdup(yytext); 
                                     return STRING; 
                                   }
[a-zA-Z][a-zA-Z0-9_]*              { 
                                     yylval.str = strdup(yytext); 
                                     return IDENTIFICADOR; 
                                   }
.                                  { yyerror("Caractere desconhecido"); }
%%

int yywrap(void) {
    return 1;
}