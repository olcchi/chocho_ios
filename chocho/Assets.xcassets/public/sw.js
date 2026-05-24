self.addEventListener("push", function (event) {
  if (!event.data) {
    return;
  }

  const data = event.data.json();
  const options = {
    body: data.body,
    icon: data.icon || "/chocho-v2.svg",
    badge: data.badge || "/chocho-v2.svg",
    data: {
      url: data.url || self.location.origin,
      dateOfArrival: Date.now(),
    },
  };

  event.waitUntil(self.registration.showNotification(data.title || "ChoCho", options));
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();

  const targetUrl =
    event.notification.data && event.notification.data.url
      ? event.notification.data.url
      : self.location.origin;

  event.waitUntil(clients.openWindow(targetUrl));
});
