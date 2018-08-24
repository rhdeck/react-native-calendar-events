"use strict";
import {
  authorizationStatus,
  authorizeEventStore,
  findCalendars,
  fetchAllEvents as swiftFetchAllEvents,
  findEventById,
  saveEvent as swiftSaveEvent,
  removeEvent as swiftRemoveEvent
} from "./RNSwiftBridge";
const fetchAllEvents = async (startDate, endDate, calendars = []) => {
  return await swiftFetchAllEvents(startDate, endDate, calendars);
};
const saveEvent = async (title, details, options = {}) => {
  return await swiftSaveEvent(title, details, options);
};
const removeEvent = async (id, options = { futureEvents: false }) => {
  return await swiftRemoveEvent(id, options);
};
const removeFutureEvents = async (id, options = { futureEvents: true }) => {
  return await swiftRemoveEvent(id, options);
};
export default {
  authorizationStatus,
  authorizeEventStore,
  findCalendars,
  fetchAllEvents,
  findEventById,
  saveEvent,
  removeEvent,
  removeFutureEvents
};
