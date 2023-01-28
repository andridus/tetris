module main

import testing

struct Receiver {
	mut:
	ok bool
}

fn main() {
	mut sub := testing.get_subscriber()
	r := Receiver{}

	sub.subscribe_method('event_foo', on_foo, r)
	sub.subscribe('event_bar', on_bar)
	sub.subscribe('event_baz', on_baz)

	println('Receive ok: ' + r.ok.str())
	testing.do_work()
	println('Receive ok: ' + r.ok.str())
}

fn on_foo(mut receiver Receiver, e &testing.EventMetadata, sender voidptr) {
	receiver.ok = true
	println('on_foo :: ' +  e.message)
}

fn on_bar(receiver voidptr, e &testing.EventMetadata, sender voidptr) {
	println('on_bar :: '+ e.message)
}

fn on_baz(receiver voidptr, e voidptr, sender &testing.Duration) {
	println('on_baz :: ' + sender.hours.str())
}