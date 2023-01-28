module testing

import eventbus
import time

const (
	eb = eventbus.new()
)

pub struct Duration {
	pub:
	hours int
}

pub struct EventMetadata {
	pub:
	message string
}

pub fn do_work() {
	duration := Duration{10}
	for i in 0..10 {
		time.sleep(500000000)

		println('working...')
		if i == 5 {

			event_metadata := &EventMetadata{'Iteration ' + i.str()}
			testing.eb.publish('event_foo', duration, event_metadata)
			testing.eb.publish('event_bar', duration, event_metadata)
		}
	}
	testing.eb.publish('event_baz', &Duration{42}, &EventMetadata{'Additional data at the end.'})
}

pub fn get_subscriber() eventbus.Subscriber {
	return *testing.eb.subscriber
}