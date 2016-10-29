> {-# LANGUAGE GADTs                     #-}
> {-# LANGUAGE ExistentialQuantification #-}
>
> module Ch05_08_dynamic_types_01 where
>
> import Ch05_07_typecase
>
> -- uses existential quantification for `t`
> data DynamicExQuan =
>     forall t. Show t => DynExQuan (Rep t) t

`DynEq` values have opaque type, but are well typed.

Use to create heterogeneous lists:

> dynExQuanList = [ DynExQuan RChar 'x'
>                 , DynExQuan RInt  3
>                 ]
>
> showDynExQuan (DynExQuan rep v) = showT rep v

But lists are in a different universe, so:

> ch05_08_1_e1 =  map showDynExQuan dynExQuanList

Since GADTs generalize existentials, can also write a "dynamic GADT":

> data Dynamic where
>   Dyn :: Show t => Rep t -> t -> Dynamic
>
> instance Show Dynamic where
>   show (Dyn rep v) = showT rep v

Use to create heterogeneous lists:

> dynList :: [Dynamic]
> dynList = [ Dyn RChar 'x'
>           , Dyn RInt 3
>           ]
>
> showDyn (Dyn rep v) = showT rep v

`showDyn` acts on dynamic values

generic `showT` acts on "generic data"

But lists are in a different universe, so:

> ch05_08_1_e2 = map showDyn dynList

See next for adding list in same universe.


