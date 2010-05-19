# encoding: utf-8

STATIC = %w{
  али без богаче бьюсь да деяши допреж доселе доставляше за знаменует и к коли
  летопись ли любо на ни не ой от отселе паче по покамест покуда пущай с сему
  сотворим твориши того убо убоже узрите челом як
}

COMMENT_BEGIN = %w{ тако }
COMMENT_END = %W{ \n }

TOKENS = {
  :whitespace => [' ', "\t"],
  :delimiter => ["\n", ','],
  :symbol => ('а'..'я').to_a + ['ё', '_'],
  :number => ('0'..'9').to_a,
  :quot => ['"']
}

PERMISSIVE_STATES = [:string, :comment]

STATES = {
  :idle => {
    :whitespace => :idle,
    :delimiter => :idle,
    :symbol => :identifier,
    :number => :number,
    :quot => :string,
  },
  :identifier => {
    :whitespace => :idle,
    :delimiter => :idle,
    :symbol => :identifier,
    :number => :identifier,
    :quot => :error
  },
  :number => {
    :whitespace => :idle,
    :delimiter => :idle,
    :symbol => :error,
    :number => :number,
    :quot => :error
  },
  :string => {
    :whitespace => :string,
    :delimiter => :string,
    :symbol => :string,
    :number => :string,
    :quot => :idle
  },
  :comment => {
    :whitespace => :comment,
    :delimiter => :idle,
    :symbol => :comment,
    :number => :comment,
    :quot => :comment
  }
}