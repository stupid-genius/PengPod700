<?xml version="1.0" encoding="UTF-8"?>
<!--

 Copyright (c) 2009 Red Hat, Inc.

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 -->

<!-- use this file with xsltproc evtest-replace.xml <input.xml>
    where <input.xml> is the xml file generated by evtest-capture.
 -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" indent="yes" encoding="UTF-8"/>


  <xsl:template match="/evtest-capture">
      <![CDATA[
/*
 Copyright (c) 2009 Red Hat, Inc.

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <dlfcn.h>

static int fd   = -1;

static void send_event(int fd, int type, int code, int value, int sec, int usec);

static int setup(struct uinput_user_dev *dev, int fd)
{
]]>
<xsl:apply-templates select="info/id"/>
<xsl:apply-templates select="info/event-type"/>
<![CDATA[

    return 0;
error:
    perror("ioctl failed.");
    return -1;
}

static int run(int fd)
{
]]>
<xsl:apply-templates select="events"/>
<![CDATA[
    return 0;
}

static int init_uinput()
{
    struct uinput_user_dev dev;

    fd = open("/dev/uinput", O_RDWR);
    if (fd < 0 && errno == ENODEV)
        fd = open("/dev/input/uinput", O_RDWR);
    if (fd < 0)
        goto error;

    memset(&dev, 0, sizeof(dev));
    setup(&dev, fd);

    if (write(fd, &dev, sizeof(dev)) < sizeof(dev))
        goto error;
    if (ioctl(fd, UI_DEV_CREATE, NULL) == -1) goto error;

    return 0;

error:
    fprintf(stderr, "Error: %s\n", strerror(errno));

    if (fd != -1)
        close(fd);

    return -1;
}

static void cleanup_uinput(void)
{
    if (fd == -1)
        return;

    ioctl(fd, UI_DEV_DESTROY, NULL);
    close(fd);
    fd = -1;
}

static void send_event(int fd, int type, int code, int value, int sec, int usec)
{
    static int sec_offset = -1;
    static long last_time = -1;
    long newtime;
    struct input_event event;

    event.type  = type;
    event.code  = code;
    event.value = value;

    if (sec_offset == -1)
        sec_offset = sec;

    sec -= sec_offset;
    newtime = sec * 1000000 + usec;

    if (last_time > 0)
        usleep(newtime - last_time);

    if (write(fd, &event, sizeof(event)) < sizeof(event))
        perror("Send event failed.");

    last_time = newtime;
}

int main (int argc, char **argv)
{
    if (init_uinput() < 0) {
        fprintf(stderr,
                "Failed to initialize /dev/input/uinput. Exiting.\n");
        return -1;
    }

    printf("Device created. Press CTRL+C to terminate.\n");
    run(fd);

    cleanup_uinput();

    return 0;
}
]]>
  </xsl:template>

  <!-- Setup the required uinput bits to make the device look real
       The funky comments at the start of the lines are just to improve
       the output indenting.
  -->
  <xsl:template match="event-type">
    if (ioctl(fd, UI_SET_EVBIT, <xsl:value-of select="@type"/>) == -1) goto error;
<!-- --><xsl:for-each select="code">
        <xsl:choose>
            <xsl:when test="../@type = 'EV_KEY'">
    if (ioctl(fd, UI_SET_KEYBIT, <xsl:value-of select="@value"/>) == -1) goto error;
<!--     --></xsl:when>
            <xsl:when test="../@type = 'EV_REL'">
    if (ioctl(fd, UI_SET_RELBIT, <xsl:value-of select="@value"/>) == -1) goto error;
<!--     --></xsl:when>
            <xsl:when test="../@type = 'EV_MSC'">
    if (ioctl(fd, UI_SET_MSCBIT, <xsl:value-of select="@value"/>) == -1) goto error;
<!--     --></xsl:when>
            <xsl:when test="../@type = 'EV_ABS'">
    if (ioctl(fd, UI_SET_ABSBIT, <xsl:value-of select="@value"/>) == -1) goto error;
    else {
        int idx = <xsl:value-of select="@value"/>;
        dev->absmin[idx] = <xsl:value-of select="@abs-min"/>;
        dev->absmax[idx] = <xsl:value-of select="@abs-max"/>;
        dev->absfuzz[idx] = <xsl:value-of select="@abs-fuzz"/>;
        dev->absflat[idx] = <xsl:value-of select="@abs-flat"/>;

        if (dev->absmin[idx] == dev->absmax[idx])
            dev->absmax[idx]++;
    }
<!--         --></xsl:when>
        </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="id">
    strcpy(dev->name, "<xsl:value-of select="."/>");
    dev->id.bustype = <xsl:value-of select="@bus"/>;
    dev->id.vendor = <xsl:value-of select="@vendor"/>;
    dev->id.product = <xsl:value-of select="@product"/>;
    dev->id.version = <xsl:value-of select="@version"/>;
  </xsl:template>

  <!-- code replaying the events -->
  <xsl:template match="events">
      <xsl:for-each select="event">
    send_event(fd, <xsl:value-of select="@type"/>, <xsl:value-of select="@code"/>, <xsl:value-of select="@value"/>, <xsl:value-of select="@sec"/>, <xsl:value-of select="@usec"/>);</xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
