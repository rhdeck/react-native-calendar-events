import { NativeModules } from "react-native";
//#region Code for object RNCalendarEvents
const NativeRNCalendarEvents = NativeModules.RNCalendarEvents;
const authorizationStatus = async () => {
  return await NativeRNCalendarEvents.authorizationStatus();
};
const authorizeEventStore = async () => {
  return await NativeRNCalendarEvents.authorizeEventStore();
};
const findCalendars = async () => {
  return await NativeRNCalendarEvents.findCalendars();
};
const fetchAllEvents = async (startDate, endDate, calendars) => {
  return await NativeRNCalendarEvents.fetchAllEvents(
    startDate,
    endDate,
    calendars
  );
};
const findEventById = async eventId => {
  return await NativeRNCalendarEvents.findEventById(eventId);
};
const saveEvent = async (title, settings, options) => {
  return await NativeRNCalendarEvents.saveEvent(title, settings, options);
};
const removeEvent = async (eventId, options) => {
  return await NativeRNCalendarEvents.removeEvent(eventId, options);
};
//#endregion
//#region Exports
export {
  authorizationStatus,
  authorizeEventStore,
  findCalendars,
  fetchAllEvents,
  findEventById,
  saveEvent,
  removeEvent
};
//#endregion
